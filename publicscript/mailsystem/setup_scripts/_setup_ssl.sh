#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

cd /usr/local
git clone https://github.com/certbot/certbot
export PATH=/usr/local/certbot:${PATH}
CERT=/etc/letsencrypt/live/${FIRST_DOMAIN}/fullchain.pem

CA=$(certbot-auto -n certonly --webroot -w ${HTTP_DOCROOT} -d ${FIRST_DOMAIN} -m admin@${FIRST_DOMAIN} --agree-tos --server https://acme-v02.api.letsencrypt.org/directory)

for x in $(seq 1 3)
do
	if [ ! -f ${CERT} ]
	then
		date
		sleep 300
		${CA}
	else
		break
	fi
done

if [ ! -f ${CERT} ]
then
	exit 1
fi

cat <<_EOL_>> /etc/postfix-inbound/main.cf
smtpd_use_tls = yes
smtpd_tls_cert_file = /etc/letsencrypt/live/${FIRST_DOMAIN}/fullchain.pem
smtpd_tls_key_file  = /etc/letsencrypt/live/${FIRST_DOMAIN}/privkey.pem
smtpd_tls_loglevel = 1
smtpd_tls_ask_ccert = yes
_EOL_

systemctl reload postfix

cat <<_EOL_> /etc/nginx/conf.d/ssl.conf
ssl_session_timeout  5m;
ssl_protocols TLSv1.2;
ssl_ciphers EECDH+AESGCM:EECDH+AES;
ssl_ecdh_curve prime256v1;
ssl_prefer_server_ciphers on;
ssl_certificate /etc/letsencrypt/live/${FIRST_DOMAIN}/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/${FIRST_DOMAIN}/privkey.pem;
_EOL_

cat <<_EOL_> /etc/nginx/conf.d/https.conf
server {
	listen 443 ssl http2 ;
	server_name ${FIRST_DOMAIN};
	index index.html, index.php;
	access_log /var/log/nginx/access_ssl.log main;
	error_log  /var/log/nginx/error_ssl.log  error;
	root ${HTTPS_DOCROOT};
	server_tokens off;
	charset     utf-8;

	location ~ \.php$ {
		fastcgi_pass 127.0.0.1:9000;
		fastcgi_index index.php;
		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		include fastcgi_params;
	}

	error_page 404 /404.html;
		location = /40x.html {
	}

	error_page 500 502 503 504 /50x.html;
		location = /50x.html {
	}

}
_EOL_

sed -i 's/^#//' /etc/nginx/mail.conf

systemctl reload nginx

R=${RANDOM}
echo "$((${R}%60)) $((${R}%24)) * * $((${R}%7)) root /usr/local/certbot/certbot-auto renew --webroot -w ${HTTP_DOCROOT} --post-hook 'systemctl reload nginx postfix'" > /etc/cron.d/certbot-auto
