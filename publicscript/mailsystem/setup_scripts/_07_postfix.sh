#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- 必要なパッケージのインストール
dnf install -y postfix {cyrus-sasl,openldap,pcre,libdb,libnsl2,mysql,openssl}-devel cyrus-sasl-plain
grep -v ExecStartPre= /usr/lib/systemd/system/postfix.service > /var/tmp/postfix.service
dnf remove -y postfix

#-- 標準の postfix では ldap が使用できないため、ソースから build する
mkdir -p ${WORKDIR}/src
cd ${WORKDIR}/src
VERSION=3.6.0
curl -O http://mirror.postfix.jp/postfix-release/official/postfix-${VERSION}.tar.gz
tar xvzf postfix-${VERSION}.tar.gz && cd postfix-${VERSION}

CCARGS="-Wmissing-prototypes -Wformat -Wno-comment -fPIC \
-DHAS_LDAP -DLDAP_DEPRECATED=1 -DHAS_PCRE -I/usr/include/pcre \
-DHAS_MYSQL -I/usr/include/mysql -DUSE_SASL_AUTH -DUSE_CYRUS_SASL \
-I/usr/include/sasl -DUSE_TLS -DDEF_CONFIG_DIR=\\\"/etc/postfix\\\""

AUXLIBS="-lldap -llber -lpcre -ldb -lnsl -lresolv -L/usr/lib64/mysql -lmysqlclient \
-lm -L/usr/lib64/sasl2 -lsasl2 -lssl -lcrypto  -pie -Wl,-z,relro,-z,now"

make -f Makefile.init makefiles CCARGS="${CCARGS}" AUXLIBS="${AUXLIBS}"
make
make upgrade
mv /var/tmp/postfix.service /usr/lib/systemd/system/

#-- postfix の設定
postmulti -e init
postmulti -I postfix-inbound -e create

postconf -c /etc/postfix -e inet_interfaces=${OUTBOUND_MTA_SERVER}
postconf -c /etc/postfix -e smtpd_milters=inet:${RSPAMD_SERVER}:${RSPAMD_PORT}
postconf -c /etc/postfix -e non_smtpd_milters=inet:${RSPAMD_SERVER}:${RSPAMD_PORT}
postconf -c /etc/postfix -e smtpd_authorized_xclient_hosts=${XAUTH_HOST}
postconf -c /etc/postfix -e smtpd_sasl_auth_enable=yes
postconf -c /etc/postfix -e smtpd_sender_restrictions=reject_sender_login_mismatch
postconf -c /etc/postfix -e myhostname=${HOSTNAME}

postconf -c /etc/postfix-inbound -X master_service_disable
postconf -c /etc/postfix-inbound -e inet_interfaces=${IPADDR}
postconf -c /etc/postfix-inbound -e myhostname=${FIRST_DOMAIN}
postconf -c /etc/postfix-inbound -e recipient_delimiter=+
postconf -c /etc/postfix-inbound -e smtpd_milters=inet:${RSPAMD_SERVER}:${RSPAMD_PORT}
postconf -c /etc/postfix-inbound -e smtpd_helo_restrictions="reject_invalid_hostname reject_non_fqdn_hostname reject_unknown_hostname"
postconf -c /etc/postfix-inbound -e smtpd_sender_restrictions="reject_non_fqdn_sender reject_unknown_sender_domain"
postconf -c /etc/postfix-inbound -e relay_domains=/etc/postfix-inbound/relay_domains
postconf -c /etc/postfix-inbound -e authorized_submit_users=static:anyone
postconf -c /etc/postfix-inbound -e smtpd_tls_CAfile=/etc/pki/tls/certs/ca-bundle.crt
postconf -c /etc/postfix-inbound -e smtpd_tls_ask_ccert=yes
postconf -c /etc/postfix-inbound -e smtpd_tls_cert_file=/etc/letsencrypt/live/${FIRST_DOMAIN}/fullchain.pem
postconf -c /etc/postfix-inbound -e smtpd_tls_key_file=/etc/letsencrypt/live/${FIRST_DOMAIN}/privkey.pem
postconf -c /etc/postfix-inbound -e smtpd_tls_ciphers=high
postconf -c /etc/postfix-inbound -e smtpd_tls_loglevel=1
postconf -c /etc/postfix-inbound -e smtpd_tls_mandatory_ciphers=high
postconf -c /etc/postfix-inbound -e 'smtpd_tls_mandatory_protocols=!SSLv2,!SSLv3,!TLSv1,!TLSv1.1'
postconf -c /etc/postfix-inbound -e 'smtpd_tls_protocols=!SSLv2,!SSLv3,!TLSv1,!TLSv1.1'
postconf -c /etc/postfix-inbound -e smtpd_tls_received_header=yes
postconf -c /etc/postfix-inbound -e smtpd_tls_session_cache_database=btree:/var/lib/postfix-inbound/smtpd_tls_session_cache
postconf -c /etc/postfix-inbound -e smtpd_use_tls=yes
postconf -c /etc/postfix-inbound -e lmtp_destination_concurrency_limit=40

for cf in /etc/postfix /etc/postfix-inbound
do
  postconf -c ${cf} -e alias_maps=hash:/etc/aliases
  postconf -c ${cf} -e inet_protocols=ipv4
  postconf -c ${cf} -e milter_default_action=tempfail
  postconf -c ${cf} -e milter_protocol=6
  postconf -c ${cf} -e milter_command_timeout=15s
  postconf -c ${cf} -e milter_connect_timeout=20s
  postconf -c ${cf} -e smtpd_junk_command_limit=20
  postconf -c ${cf} -e smtpd_helo_required=yes
  postconf -c ${cf} -e smtpd_hard_error_limit=5
  postconf -c ${cf} -e message_size_limit=20480000
  # postconf -c ${cf} -e anvil_rate_time_unit=60s
  # postconf -c ${cf} -e smtpd_recipient_limit=50
  # postconf -c ${cf} -e smtpd_client_connection_count_limit=15
  # postconf -c ${cf} -e smtpd_client_message_rate_limit=100
  # postconf -c ${cf} -e smtpd_client_recipient_rate_limit=200
  # postconf -c ${cf} -e smtpd_client_connection_rate_limit=100
  postconf -c ${cf} -e disable_vrfy_command=yes
  postconf -c ${cf} -e smtpd_discard_ehlo_keywords=dsn,enhancedstatuscodes,etrn
  postconf -c ${cf} -e lmtp_host_lookup=native
  postconf -c ${cf} -e smtp_host_lookup=native
  postconf -c ${cf} -e smtp_tls_CAfile=/etc/pki/tls/certs/ca-bundle.crt
  postconf -c ${cf} -e smtp_tls_cert_file=/etc/letsencrypt/live/${FIRST_DOMAIN}/fullchain.pem
  postconf -c ${cf} -e smtp_tls_key_file=/etc/letsencrypt/live/${FIRST_DOMAIN}/privkey.pem
  postconf -c ${cf} -e smtp_tls_loglevel=1
  postconf -c ${cf} -e smtp_tls_security_level=may
  postconf -c ${cf} -e smtp_use_tls=yes
  postconf -c ${cf} -e tls_high_cipherlist=EECDH+AESGCM
  postconf -c ${cf} -e tls_preempt_cipherlist=yes
  postconf -c ${cf} -e tls_random_source=dev:/dev/urandom
  postconf -c ${cf} -e tls_ssl_options=NO_RENEGOTIATION
done

tmpcf=$(for x in $(seq ${MIN_DOMAIN_LEVEL} ${MAX_DOMAIN_LEVEL}); do printf "ldap:/etc/postfix-inbound/ldaptransport${x}.cf "; done)
postconf -c /etc/postfix-inbound -e transport_maps="${tmpcf}"
tmpcf=$(for x in $(seq ${MIN_DOMAIN_LEVEL} ${MAX_DOMAIN_LEVEL}); do printf "ldap:/etc/postfix-inbound/ldapvirtualalias${x}.cf "; done)
postconf -c /etc/postfix-inbound -e virtual_alias_maps="${tmpcf}"
tmpcf=$(for x in $(seq ${MIN_DOMAIN_LEVEL} ${MAX_DOMAIN_LEVEL}); do printf "ldap:/etc/postfix-inbound/ldaprcptcheck${x}.cf "; done)
postconf -c /etc/postfix-inbound -e smtpd_recipient_restrictions="check_recipient_access ${tmpcf} reject"
tmpcf=$(for x in $(seq ${MIN_DOMAIN_LEVEL} ${MAX_DOMAIN_LEVEL}); do printf "ldap:/etc/postfix/ldapsendercheck${x}.cf "; done)
postconf -c /etc/postfix -e smtpd_sender_login_maps="${tmpcf}"

for x in $(seq ${MIN_DOMAIN_LEVEL} ${MAX_DOMAIN_LEVEL})
do
	sb="search_base = "
	for y in $(seq ${x} -1 1)
	do
		sb="${sb}dc=%${y},"
	done
	sb=$(echo ${sb} | sed 's/,$//')

	cat <<-_EOL_>/etc/postfix-inbound/ldaprcptcheck${x}.cf
	server_host = ${LDAP_SERVER}
	bind = no
	version = 3
	scope = sub
	timeout = 15
	query_filter = (&(objectClass=mailRecipient)(mailAlternateAddress=%s))
	result_attribute = mailRoutingAddress
	result_format = OK
	${sb}
	_EOL_

	cat <<-_EOL_>/etc/postfix-inbound/ldaptransport${x}.cf
	server_host = ${LDAP_SERVER}
	bind = no
	version = 3
	scope = sub
	timeout = 15
	query_filter = (&(objectClass=mailRecipient)(mailAlternateAddress=%s))
	result_attribute = mailMessageStore
	result_format = lmtp:[%s]:${LMTP_PORT}
	${sb}
	_EOL_

	cp /etc/postfix-inbound/ldaprcptcheck${x}.cf /etc/postfix-inbound/ldapvirtualalias${x}.cf
	sed -i 's/result_format = OK/result_format = %s/' /etc/postfix-inbound/ldapvirtualalias${x}.cf

	cat <<-_EOL_>/etc/postfix/ldapsendercheck${x}.cf
	server_host = ${LDAP_SERVER}
	bind = no
	version = 3
	scope = sub
	timeout = 15
	query_filter = (&(objectClass=mailRecipient)(mailRoutingAddress=%s))
	result_attribute = mailRoutingAddress
	result_format = %s
	${sb}
	_EOL_

done

#-- ドメインの追加
for domain in ${DOMAIN_LIST}
do
cat <<_EOL_>>/etc/postfix-inbound/relay_domains
${domain}
_EOL_
done

#-- postfix の再起動と postfix-inbound インスタンスの有効化
systemctl enable postfix
systemctl start postfix
postmulti -i postfix-inbound -e enable
postmulti -i postfix-inbound -p start

#-- OS再起動時にpostfixの起動に失敗することがあるので、その対応
sed -i -e "s/^After=syslog.target.*/After=syslog.target network.target NetworkManager-wait-online.service/" /usr/lib/systemd/system/postfix.service
systemctl daemon-reload

#-- aliases の設定変更
sed -i "s/^postmaster:.*/postmaster:	root@${FIRST_DOMAIN}/" /etc/aliases
newaliases

