#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- リポジトリの設定と nginx, php7.2 のインストール
dnf install -y nginx php php-{fpm,ldap,devel,xml,pear,json}

#-- php, php-fpm の設定
cp -p /etc/php.ini{,.org}
sed -i -e "s/^max_execution_time = 30/max_execution_time = 300/" \
       -e "s/^max_input_time = 60/max_input_time = 300/" \
       -e "s/^post_max_size = 8M/post_max_size = 20M/" \
       -e "s/^upload_max_filesize = 2M/upload_max_filesize = 20M/" \
       -e "s/^;date.timezone =/date.timezone = 'Asia\/Tokyo'/" /etc/php.ini

cp -p /etc/php-fpm.d/www.conf{,.org}
sed -i -e "s/user = apache/user = nginx/" -e "s/group = apache/group = nginx/" /etc/php-fpm.d/www.conf
#-- 10000 ユーザ対応
sed -i -e 's/^;php_admin_value\[memory_limit\] = 128M/php_admin_value\[memory_limit\] = 256M/' /etc/php-fpm.d/www.conf

chown nginx /var/log/php-fpm
chgrp nginx /var/lib/php/*

#-- php を update すると、permission が apache に戻るのでその対策
cat <<_EOL_>> ${CRONFILE}
* * * * * root chown nginx /var/log/php-fpm >/dev/null 2>&1
* * * * * root chgrp nginx /var/lib/php/{opcache,session,wsdlcache} >/dev/null 2>&1
_EOL_

RESOLVER1=$(awk '/^nameserver/{print $2}' /etc/resolv.conf | head -1)
RESOLVER2=$(awk '/^nameserver/{print $2}' /etc/resolv.conf | tail -1)

#-- nginx mail proxy の設定
cat <<_EOL_> /etc/nginx/mail.conf
mail {
  auth_http  127.0.0.1/nginx_mail_proxy/ldap_authentication.php ;
  proxy on;
  proxy_pass_error_message on;
  include /etc/nginx/default.d/${FIRST_DOMAIN}_ssl.conf;
  ssl_session_cache shared:MAIL:10m;
  smtp_capabilities PIPELINING 8BITMIME "SIZE 20480000";
  pop3_capabilities TOP USER UIDL;
  imap_capabilities IMAP4rev1;
  smtp_auth login plain;

  server {
    listen     ${IPADDR}:587;
    protocol   smtp;
    starttls   on;
    xclient    on;
    resolver   ${RESOLVER1} ${RESOLVER2};
    auth_http_header PORT 587;
  }
  server {
    listen     ${IPADDR}:465;
    protocol   smtp;
    ssl        on;
    xclient    on;
    resolver   ${RESOLVER1} ${RESOLVER2};
    auth_http_header PORT 465;
  }
  server {
    listen     ${IPADDR}:995;
    protocol   pop3;
    ssl        on;
    auth_http_header PORT 995;
  }
  server {
    listen     ${IPADDR}:993;
    protocol   imap;
    ssl        on;
    auth_http_header PORT 993;
  }
}
_EOL_

cp -p /etc/nginx/nginx.conf{,.org}

#-- nginx の設定
cat <<'_EOL_'> /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections  1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    include /etc/nginx/conf.d/*.conf;
}
include /etc/nginx/mail.conf;
_EOL_

cat <<_EOL_> /etc/nginx/default.d/${FIRST_DOMAIN}_ssl.conf
ssl_protocols TLSv1.2 TLSv1.3 ;
ssl_ciphers EECDH+AESGCM;
ssl_ecdh_curve prime256v1;
ssl_prefer_server_ciphers on;
ssl_session_timeout  5m;
ssl_certificate /etc/letsencrypt/live/${FIRST_DOMAIN}/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/${FIRST_DOMAIN}/privkey.pem;
ssl_trusted_certificate /etc/letsencrypt/live/${FIRST_DOMAIN}/chain.pem;
resolver ${RESOLVER1} ${RESOLVER2} valid=300s;
resolver_timeout 10s;
_EOL_

cat <<_EOL_> /etc/nginx/conf.d/http.conf
server {
  listen ${IPADDR}:80;
  server_name _;
  return 301 https://${FIRST_DOMAIN}\$request_uri;
}

server {
  listen 127.0.0.1:80;
  server_name _;
  index index.html, index.php;
  access_log /var/log/nginx/access_auth.log main;
  error_log  /var/log/nginx/error_auth.log  error;
  root ${HTTP_DOCROOT};
  server_tokens off;
  charset     utf-8;

  location ~ \.php\$ {
    allow 127.0.0.1;
    fastcgi_pass unix:/run/php-fpm/www.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    include fastcgi_params;
    deny all;
  }

  error_page 404 /404.html;
    location = /404.html {
  }
  error_page 500 502 503 504 /50x.html;
    location = /50x.html {
  }
}
_EOL_

mkdir -p ${HTTP_DOCROOT} ${HTTPS_DOCROOT} /var/log/nginx /var/cache/nginx/client_temp /etc/nginx/conf.d/https.d
cp -p /usr/share/nginx/html/[45]*.html /usr/share/nginx/html/*.png ${HTTP_DOCROOT}
cp -p /usr/share/nginx/html/[45]*.html /usr/share/nginx/html/*.png ${HTTPS_DOCROOT}
chown -R nginx. /var/www/html/ /var/log/nginx /var/cache/nginx/client_temp

cat <<_EOL_> /etc/nginx/conf.d/https.conf
server {
  listen 443 ssl http2 default_server;
  server_name ${FIRST_DOMAIN};
  include /etc/nginx/default.d/${FIRST_DOMAIN}_ssl.conf;
  index index.html, index.php;
  access_log /var/log/nginx/access_ssl.log main;
  error_log  /var/log/nginx/error_ssl.log  error;
  root ${HTTPS_DOCROOT};
  server_tokens off;
  charset     utf-8;

  ssl_session_cache shared:WEB:10m;
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
  ssl_stapling on ;
  ssl_stapling_verify on ;

  include /etc/nginx/conf.d/https.d/*.conf;

  location ~ \.php\$ {
    fastcgi_pass unix:/run/php-fpm/www.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME \$document_root/\$fastcgi_script_name;
    include fastcgi_params;
  }

  error_page 404 /404.html;
    location = /404.html {
  }
  error_page 500 502 503 504 /50x.html;
    location = /50x.html {
  }

}
_EOL_

#-- nginx-mail-proxy用の認証スクリプトを作成
mkdir -p ${HTTP_DOCROOT}/nginx_mail_proxy
cp -p $(dirname $0)/../tools/ldap_authentication.php ${HTTP_DOCROOT}/nginx_mail_proxy/
sed -i "s/#IPV4/${IPADDR}/" ${HTTP_DOCROOT}/nginx_mail_proxy/ldap_authentication.php

#-- phpredis のインストール
dnf install -y re2c
pecl channel-update pecl.php.net
echo "no" | pecl install redis
echo extension=redis.so  >> /etc/php.d/99-redis.ini

#-- nginx, php-fpm の起動
systemctl enable nginx php-fpm
systemctl start nginx php-fpm

#-- OS再起動時にnginxの起動に失敗することがあるので、その対応
sed -i -e "s/^\(After=network.target remote-fs.target nss-lookup.target\)/\1 NetworkManager-wait-online.service postfix.service/" /usr/lib/systemd/system/nginx.service
systemctl daemon-reload

#-- firewall の設定
firewall-cmd --permanent --add-port={25,587,465,993,995,80,443}/tcp
firewall-cmd --reload
