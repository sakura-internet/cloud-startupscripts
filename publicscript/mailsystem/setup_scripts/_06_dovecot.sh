#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- dovecot のインストール
dnf install -y dovecot dovecot-pigeonhole openldap-devel expat-devel bzip2-devel zlib-devel

#-- dovecot の設定
cat <<_EOL_> /etc/dovecot/local.conf
postmaster_address = postmater@${FIRST_DOMAIN}
auth_mechanisms = plain login
deliver_log_format = from=%{from_envelope}, to=%{to_envelope}, size=%p, msgid=%m, delivery_time=%{delivery_time}, session_time=%{session_time}, %\$
disable_plaintext_auth = no
first_valid_uid = 97
mail_location = maildir:/var/dovecot/%Ld/%Ln
mail_plugins = \$mail_plugins zlib
plugin {
  sieve = /var/dovecot/%Ld/%Ln/dovecot.sieve
  sieve_extensions = +notify +imapflags +editheader +vacation-seconds
  sieve_max_actions = 32
  sieve_max_redirects = 10
  sieve_redirect_envelope_from = recipient
  sieve_vacation_min_period = 1h
  sieve_vacation_default_period = 7d
  sieve_vacation_max_period = 60d
  zlib_save = bz2
  zlib_save_level = 5
}
protocols = imap pop3 lmtp sieve
service imap-login {
  inet_listener imap {
    address = ${DOVECOT_SERVER}
  }
}
service lmtp {
  inet_listener lmtp {
    address = ${DOVECOT_SERVER}
    port = ${LMTP_PORT}
  }
}
service pop3-login {
  inet_listener pop3 {
    address = ${DOVECOT_SERVER}
  }
}
service managesieve-login {
  inet_listener sieve {
    address = ${DOVECOT_SERVER}
  }
}
protocol lmtp {
  mail_plugins = \$mail_plugins sieve
}
protocol imap {
  mail_max_userip_connections = 20
}
ssl = no
ssl_cert =
ssl_key =
lmtp_save_to_detail_mailbox = yes
lda_mailbox_autocreate = yes
passdb {
  driver = static
  args = nopassword=y
}
userdb {
  args = uid=dovecot gid=dovecot home=/var/dovecot/%Ld/%Ln allow_all_users=yes
  driver = static
}
_EOL_

cnt=1
for base in $(for domain in ${DOMAIN_LIST}
  do
    tmpdc=""
    for dc in $(echo ${domain} | sed 's/\./ /g')
    do
      tmpdc="${tmpdc}dc=${dc},"
    done
    echo ${tmpdc}
  done | sed 's/,$//')
do
cat <<_EOL_>>/etc/dovecot/local.conf
userdb {
  args = /etc/dovecot/dovecot-ldap${cnt}.conf.ext
  driver = ldap
}
_EOL_

cat <<_EOL_>/etc/dovecot/dovecot-ldap${cnt}.conf.ext
hosts = ${LDAP_SERVER}
auth_bind = yes
base = ${base}
pass_attrs=mailRoutingAddress=User,userPassword=password
pass_filter = (mailRoutingAddress=%u)
user_attrs = \
  =uid=dovecot, \
  =gid=dovecot, \
  =mail=maildir:/var/dovecot/%Ld/%Ln, \
  =home=/var/dovecot/%Ld/%Ln
user_filter = (mailRoutingAddress=%u)
iterate_attrs = mailRoutingAddress=user
iterate_filter = (mailRoutingAddress=*)
_EOL_

  cnt=$(($cnt + 1))
done

sed -i 's/^\!include auth-system.conf.ext/#\|include auth-system.conf.ext/' /etc/dovecot/conf.d/10-auth.conf

mkdir /var/dovecot
chown dovecot. /var/dovecot

#-- dovecot の起動
systemctl enable dovecot
systemctl start dovecot

