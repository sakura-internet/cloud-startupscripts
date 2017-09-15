#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

mkdir -p ${HTTPS_DOCROOT}/rainloop
cd ${HTTPS_DOCROOT}/rainloop
curl -sL https://repository.rainloop.net/installer.php | php
chown -R nginx. ${HTTPS_DOCROOT}/rainloop

curl -s https://${FIRST_DOMAIN}/rainloop/

RLCONF=${HTTPS_DOCROOT}/rainloop/data/_data_/_default_/configs/application.ini
sed -i -e 's/"en"/"ja_JP"/' \
-e 's/determine_user_domain = Off/determine_user_domain = On/' \
-e 's/attachment_size_limit = 25/attachment_size_limit = 20/' ${RLCONF}

for x in $(ldapsearch -x mailroutingaddress | awk -F@ '/^mailRoutingAddress/{print $2}' | sort | uniq)
do
	cat <<-_EOL_> ${HTTPS_DOCROOT}/rainloop/data/_data_/_default_/domains/${x}.ini
	imap_host = "${FIRST_DOMAIN}"
	imap_port = 993
	imap_secure = "SSL"
	imap_short_login = Off
	sieve_use = Off
	sieve_allow_raw = Off
	sieve_host = ""
	sieve_port = 4190
	sieve_secure = "None"
	smtp_host = "${FIRST_DOMAIN}"
	smtp_port = 465
	smtp_secure = "SSL"
	smtp_short_login = Off
	smtp_auth = On
	smtp_php_mail = Off
	_EOL_
	chown nginx. ${HTTPS_DOCROOT}/rainloop/data/_data_/_default_/domains/${x}.ini
done

sed -i 's/$/,gmail.com/' ${HTTPS_DOCROOT}/rainloop/data/_data_/_default_/domains/disabled
