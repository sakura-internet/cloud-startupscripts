#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

cat <<_EOL_> /etc/yum.repos.d/dovecot.repo
[dovecot-2.3-latest]
name=Dovecot 2.3 CentOS $releasever - \$basearch
baseurl=http://repo.dovecot.org/ce-2.3-latest/centos/\$releasever/RPMS/\$basearch
gpgkey=https://repo.dovecot.org/DOVECOT-REPO-GPG
gpgcheck=1
enabled=1
_EOL_

yum install -y dovecot dovecot-pigeonhole 
yum install -y openldap-devel expat-devel bzip2-devel zlib-devel

sed -i 's/^#protocols = .*/protocols = imap pop3 lmtp sieve/' /etc/dovecot/dovecot.conf
sed -i 's/^#disable_plaintext_auth.*/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's/^auth_mechanisms.*/auth_mechanisms = plain login/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's/auth-system.conf.ext/auth-static.conf.ext/' /etc/dovecot/conf.d/10-auth.conf

cat <<_EOL_>/etc/dovecot/conf.d/auth-static.conf.ext
passdb {
	 driver = static
	 args = nopassword=y
}
userdb {
	driver = static
	args = uid=dovecot gid=dovecot home=/var/dovecot/%Ld/%Ln allow_all_users=yes
}
userdb {
	driver = ldap
	args = /etc/dovecot/conf.d/dovecot-ldap.conf.ext
}
_EOL_

cat <<_EOL_>/etc/dovecot/conf.d/dovecot-ldap.conf.ext
hosts = ${LDAP_SERVER}
auth_bind = yes
base = ""
pass_attrs=mailRoutingAddress=User,userPassword=password
pass_filter = (&(objectClass=inetLocalMailRecipient)(mailRoutingAddress=%u))
iterate_attrs = mailRoutingAddress=user
iterate_filter = (&(objectClass=inetLocalMailRecipient)(mailRoutingAddress=*))
_EOL_

echo 'deliver_log_format = from=%{from_envelope}, to=%{to_envelope}, size=%p, msgid=%m, delivery_time=%{delivery_time}, session_time=%{session_time}, %$' >> /etc/dovecot/conf.d/10-logging.conf
#echo 'deliver_log_format = from=%{from_envelope}, size=%p, msgid=%m %$' >> /etc/dovecot/conf.d/10-logging.conf

sed -i 's#^\#mail_location .*#mail_location = maildir:/var/dovecot/%Ld/%Ln#' /etc/dovecot/conf.d/10-mail.conf
sed -i 's/^#first_valid_uid.*/first_valid_uid = 97/' /etc/dovecot/conf.d/10-mail.conf
cat <<_EOL_>>/etc/dovecot/conf.d/10-mail.conf

mail_plugins = \$mail_plugins zlib

plugin {
	zlib_save_level = 5
	zlib_save = bz2
}
_EOL_

mkdir /var/dovecot
chown dovecot. /var/dovecot

cat <<_EOL_>/etc/dovecot/conf.d/10-master.conf
service imap-login {
	inet_listener imap {
		address = ${DOVECOT_SERVER}
	}
	inet_listener imaps {
	}
}
service pop3-login {
	inet_listener pop3 {
		address = ${DOVECOT_SERVER}
	}
	inet_listener pop3s {
	}
}
service lmtp {
	inet_listener lmtp {
		address = ${DOVECOT_SERVER}
		port = ${LMTP_PORT}
	}
}
service imap {
}
service pop3 {
}
service auth {
	unix_listener auth-userdb {
	}
}
service auth-worker {
}
service dict {
	unix_listener dict {
	}
}
_EOL_

sed -i 's/^#ssl = yes/ssl = no/' /etc/dovecot/conf.d/10-ssl.conf
sed -i 's/^ssl_cert =.*/#ssl_cert =/' /etc/dovecot/conf.d/10-ssl.conf
sed -i 's/^ssl_key =.*/#ssl_key =/' /etc/dovecot/conf.d/10-ssl.conf

sed -i "s/^#postmaster_address.*/postmaster_address = postmaster@${FIRST_DOMAIN}/" /etc/dovecot/conf.d/15-lda.conf
sed -i 's/^  #mail_plugins =.*/  mail_plugins = $mail_plugins sieve/' /etc/dovecot/conf.d/15-lda.conf
sed -i 's/^#lda_mailbox_autocreate = no/lda_mailbox_autocreate = yes/' /etc/dovecot/conf.d/15-lda.conf
sed -i 's/^  #mail_plugins =.*/  mail_plugins = $mail_plugins sieve/' /etc/dovecot/conf.d/20-lmtp.conf
sed -i 's/^#lmtp_save_to_detail_mailbox = no/lmtp_save_to_detail_mailbox = yes/' /etc/dovecot/conf.d/20-lmtp.conf

cat <<_EOL_>/etc/dovecot/conf.d/20-managesieve.conf
service managesieve-login {
}
service managesieve {
}
protocol sieve {
}
_EOL_

cat <<_EOL_>/etc/dovecot/conf.d/90-sieve.conf
plugin {
	sieve = /var/dovecot/%Ld/%Ln/dovecot.sieve
	sieve_extensions = +editheader
	sieve_redirect_envelope_from = recipient
	sieve_max_actions = 32
	sieve_max_redirects = 10
}
_EOL_

systemctl enable dovecot
systemctl start dovecot
