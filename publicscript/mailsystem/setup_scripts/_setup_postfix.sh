#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

yum install -y cyrus-sasl-plain

alternatives --set mta /usr/sbin/sendmail.postfix
yum remove -y sendmail

# setup postfix
postmulti -e init
postmulti -I postfix-inbound -e create

postconf -c /etc/postfix -e inet_interfaces=${OUTBOUND_MTA_SERVER}
postconf -c /etc/postfix -e inet_protocols=ipv4
postconf -c /etc/postfix -e smtpd_milters=inet:${CLAMAV_SERVER}:${CLAMAV_PORT},inet:${DKIM_SERVER}:${DKIM_PORT}
postconf -c /etc/postfix -e non_smtpd_milters=inet:${DKIM_SERVER}:${DKIM_PORT}
postconf -c /etc/postfix -e smtpd_authorized_xclient_hosts=${XAUTH_HOST}
postconf -c /etc/postfix -e smtpd_sasl_auth_enable=yes
postconf -c /etc/postfix -e smtpd_sender_restrictions=reject_sender_login_mismatch
postconf -c /etc/postfix -e smtpd_sender_login_maps=ldap:/etc/postfix/ldapsendercheck.cf

postconf -c /etc/postfix-inbound -e inet_interfaces=${IPADDR}
postconf -c /etc/postfix-inbound -e inet_protocols=ipv4
postconf -c /etc/postfix-inbound -e myhostname=${FIRST_DOMAIN}
postconf -c /etc/postfix-inbound -e recipient_delimiter=+
postconf -c /etc/postfix-inbound -e smtpd_milters=inet:${CLAMAV_SERVER}:${CLAMAV_PORT},inet:${ENMA_SERVER}:${ENMA_PORT}
postconf -c /etc/postfix-inbound -e smtpd_helo_restrictions=reject_invalid_hostname
postconf -c /etc/postfix-inbound -e transport_maps=ldap:/etc/postfix-inbound/ldaptransport.cf
postconf -c /etc/postfix-inbound -e virtual_alias_maps=ldap:/etc/postfix-inbound/ldapvirtualalias.cf
postconf -c /etc/postfix-inbound -e relay_domains=ldap:/etc/postfix-inbound/ldaprelaydomains.cf
postconf -c /etc/postfix-inbound -e authorized_submit_users=static:anyone
postconf -c /etc/postfix-inbound -X master_service_disable

cat <<_EOL_>> /etc/postfix-inbound/main.cf
smtpd_recipient_restrictions =
	check_recipient_access ldap:/etc/postfix-inbound/ldaprcptcheck.cf
	reject
_EOL_

# 送信アーカイブ設定があるか確認
if [ -f "/etc/postfix/sender_bcc_maps" ]
then
	# 受信アーカイブ設定
	postconf -c /etc/postfix-inbound -e recipient_bcc_maps=regexp:/etc/postfix-inbound/recipient_bcc_maps

	mv /etc/postfix/recipient_bcc_maps /etc/postfix-inbound/recipient_bcc_maps
fi

for cf in /etc/postfix/main.cf /etc/postfix-inbound/main.cf
do
	cat <<-_EOL_>> ${cf}
	milter_default_action = tempfail
	milter_protocol = 6
	smtpd_junk_command_limit = 20
	smtpd_helo_required = yes
	smtpd_hard_error_limit = 5
	message_size_limit = 20480000
	# anvil_rate_time_unit = 60s
	# smtpd_recipient_limit = 50
	# smtpd_client_connection_count_limit = 15
	# smtpd_client_message_rate_limit = 100
	# smtpd_client_recipient_rate_limit = 200
	# smtpd_client_connection_rate_limit = 100
	disable_vrfy_command = yes
	smtpd_discard_ehlo_keywords = dsn, enhancedstatuscodes, etrn
	lmtp_host_lookup = native
	smtp_host_lookup = native
	tls_random_source = dev:/dev/urandom
	_EOL_
done

cat <<_EOL_>/etc/postfix-inbound/ldaprcptcheck.cf
server_host = ${LDAP_SERVER}
bind = no
version = 3
scope = sub
timeout = 15
query_filter = (&(objectClass=inetLocalMailRecipient)(mailLocalAddress=%s))
result_attribute = mailRoutingAddress
result_format = OK
_EOL_

cat <<_EOL_>/etc/postfix-inbound/ldaptransport.cf
server_host = ${LDAP_SERVER}
bind = no
version = 3
scope = sub
timeout = 15
query_filter = (&(objectClass=inetLocalMailRecipient)(mailLocalAddress=%s))
result_attribute = mailHost
result_format = lmtp:[%s]:${LMTP_PORT}
_EOL_

# 重要: admin ユーザの description が relay対象ドメイン
cat <<_EOL_>/etc/postfix-inbound/ldaprelaydomains.cf
server_host = ${LDAP_SERVER}
bind = no
version = 3
scope = sub
timeout = 15
query_filter = (&(objectClass=inetLocalMailRecipient)(uid=admin)(description=%s))
result_attribute = description
_EOL_

cp /etc/postfix-inbound/ldaprcptcheck.cf /etc/postfix-inbound/ldapvirtualalias.cf
sed -i 's/result_format = OK/result_format = %s/' /etc/postfix-inbound/ldapvirtualalias.cf

cat <<_EOL_>/etc/postfix/ldapsendercheck.cf
server_host = ${LDAP_SERVER}
bind = no
version = 3
scope = sub
timeout = 15
query_filter = (&(objectClass=inetLocalMailRecipient)(mailRoutingAddress=%s))
result_attribute = mailRoutingAddress
result_format = %s
_EOL_

systemctl restart postfix

postmulti -i postfix-inbound -e enable
postmulti -i postfix-inbound -p start

sed -i "s/^postmaster:.*/postmaster:	root@${FIRST_DOMAIN}/" /etc/aliases
newaliases

