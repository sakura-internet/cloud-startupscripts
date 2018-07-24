#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

yum install -y nginx php-fpm php php-ldap php-devel

mkdir -p ${HTTP_DOCROOT}/{nginx_mail_proxy,mail}
mkdir -p ${HTTPS_DOCROOT}
chown -R nginx. ${HTTP_DOCROOT} ${HTTPS_DOCROOT}

# nginx.conf
mv /etc/nginx/nginx.conf{,.backup}
cp templates/nginx.conf /etc/nginx/nginx.conf
cp /usr/share/nginx/html/* ${HTTP_DOCROOT}/
cp /usr/share/nginx/html/* ${HTTPS_DOCROOT}/

DNS_SERVER=$(awk '/^nameserver/{print $2}' /etc/resolv.conf  | head -1)

cat <<_EOL_> /etc/nginx/conf.d/http.conf
server {
	listen ${IPADDR}:80 ;
	server_name ${FIRST_DOMAIN};
	access_log /var/log/nginx/access.log main;
	error_log  /var/log/nginx/error.log  error;
	root ${HTTP_DOCROOT};
	charset utf-8;

	location ^~ /.well-known/acme-challenge/ {}
	location ^~ /mail/ {}
	location /nginx_mail_proxy/ { deny all; }

	error_page 404 /404.html;
		location = /40x.html {
	}

	error_page 500 502 503 504 /50x.html;
		location = /50x.html {
	}
}
server {
	listen 127.0.0.1:80 ;
	server_name _;
	access_log /var/log/nginx/access.log main;
	error_log  /var/log/nginx/error.log  error;
	root ${HTTP_DOCROOT};
	charset utf-8;

	location ~ \.php$ {
		fastcgi_pass 127.0.0.1:9000;
		fastcgi_index index.php;
		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		include fastcgi_params;
	}
}
_EOL_

cat <<_EOL_> /etc/nginx/mail.conf
mail {
	auth_http  127.0.0.1/nginx_mail_proxy/ldap_authentication.php ;
	proxy on;
	proxy_pass_error_message on;
#	include /etc/nginx/conf.d/ssl.conf;
#	ssl_session_cache shared:MAIL:10m;
	smtp_capabilities PIPELINING 8BITMIME "SIZE 20480000";
	pop3_capabilities TOP USER UIDL;
	imap_capabilities IMAP4rev1 LITERAL+ SASL-IR LOGIN-REFERRALS ID ENABLE IDLE AUTH=LOGIN;
	smtp_auth login plain;

	server {
		listen     ${IPADDR}:587;
		protocol   smtp;
#		starttls   on;
		xclient    on;
		auth_http_header PORT 587;
		resolver   ${DNS_SERVER};
		resolver_timeout 20s;
	}
#	server {
#		listen     ${IPADDR}:465;
#		protocol   smtp;
#		ssl        on;
#		xclient    on;
#		auth_http_header PORT 465;
#		resolver   ${DNS_SERVER};
#		resolver_timeout 20s;
#	}
##	server {
##		listen     ${IPADDR}:110;
##		protocol   pop3;
##		ssl        off;
##		auth_http_header PORT 110;
##		resolver   ${DNS_SERVER};
##		resolver_timeout 20s;
##	}
##	server {
##		listen     ${IPADDR}:143;
##		protocol   imap;
##		ssl        off;
##		auth_http_header PORT 143;
##		resolver   ${DNS_SERVER};
##		resolver_timeout 20s;
##	}
#	server {
#		listen     ${IPADDR}:995;
#		protocol   pop3;
#		ssl        on;
#		auth_http_header PORT 995;
#		resolver   ${DNS_SERVER};
#		resolver_timeout 20s;
#	}
#	server {
#		listen     ${IPADDR}:993;
#		protocol   imap;
#		ssl        on;
#		auth_http_header PORT 993;
#		resolver   ${DNS_SERVER};
#		resolver_timeout 20s;
#	}
}
_EOL_

sed -i 's/^user = apache/user = nginx/' /etc/php-fpm.d/www.conf
sed -i 's/^group = apache/group = nginx/' /etc/php-fpm.d/www.conf

chown -R nginx. /var/lib/php /var/log/php-fpm
chmod 700 /var/log/php-fpm

sed -i "s/_LDAP_SERVER_/${LDAP_SERVER}/" script/ldap_authentication.php
cp -p script/ldap_authentication.php ${HTTP_DOCROOT}/nginx_mail_proxy/

systemctl enable php-fpm
systemctl enable nginx
systemctl start php-fpm
systemctl start nginx
