#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- リポジトリの設定と nginx, php7.3 のインストール
rpm -Uvh https://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum install -y nginx php73-php php73-php-{fpm,ldap,devel}

#-- php, php-fpm の設定
cp -p /etc/opt/remi/php73/php.ini{,.org}
sed -i -e "s/^max_execution_time = 30/max_execution_time = 300/" \
       -e "s/^max_input_time = 60/max_input_time = 300/" \
       -e "s/^post_max_size = 8M/post_max_size = 20M/" \
       -e "s/^upload_max_filesize = 2M/upload_max_filesize = 20M/" \
       -e "s/^;date.timezone =/date.timezone = 'Asia\/Tokyo'/" /etc/opt/remi/php73/php.ini
ln -s php73 /usr/bin/php

cp -p /etc/opt/remi/php73/php-fpm.d/www.conf{,.org}
sed -i "s/apache/nginx/" /etc/opt/remi/php73/php-fpm.d/www.conf
chown nginx /var/opt/remi/php73/log/php-fpm
chgrp nginx /var/opt/remi/php73/lib/php/*
ln -s /var/opt/remi/php73/log/php-fpm /var/log/php-fpm

#-- php を update すると、permission が apache に戻るのでその対策
cat <<_EOL_>> ${CRONFILE}
* * * * * root chown nginx /var/opt/remi/php73/log/php-fpm >/dev/null 2>&1
* * * * * root chgrp nginx /var/opt/remi/php73/lib/php/{opcache,session,wsdlcache} >/dev/null 2>&1
_EOL_

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
    resolver   8.8.8.8;
    auth_http_header PORT 587;
  }
  server {
    listen     ${IPADDR}:465;
    protocol   smtp;
    ssl        on;
    xclient    on;
    resolver   8.8.8.8;
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
user  nginx;
worker_processes  2;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include /etc/nginx/conf.d/*.conf;
}
include /etc/nginx/mail.conf;
_EOL_

cat <<_EOL_> /etc/nginx/default.d/${FIRST_DOMAIN}_ssl.conf
ssl_protocols TLSv1.2 ;
ssl_ciphers EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH;
ssl_ecdh_curve prime256v1;
ssl_prefer_server_ciphers on;
ssl_session_timeout  5m;
ssl_certificate /etc/letsencrypt/live/${FIRST_DOMAIN}/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/${FIRST_DOMAIN}/privkey.pem;
ssl_trusted_certificate /etc/letsencrypt/live/${FIRST_DOMAIN}/chain.pem;
resolver          8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout  10s;
_EOL_

cat <<_EOL_> /etc/nginx/conf.d/http.conf
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
    fastcgi_pass 127.0.0.1:9000;
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
    fastcgi_pass 127.0.0.1:9000;
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
cat <<'_EOL_'> ${HTTP_DOCROOT}/nginx_mail_proxy/ldap_authentication.php
<?php

error_reporting(0);

// write syslog
function _writelog($message) {
  openlog("nginx-mail-proxy", LOG_PID, LOG_MAIL);
  syslog(LOG_INFO,"$message") ;
  closelog();
}

// ldap authentication
function _ldapauth($server,$port,$dn,$passwd) {
  $conn = ldap_connect($server, $port);
  if ($conn) {
    ldap_set_option($conn, LDAP_OPT_PROTOCOL_VERSION, 3);
    $bind = ldap_bind($conn, $dn, $passwd);
    if ($bind) {
      ldap_close($conn);
      return True;
    } else {
      ldap_close($conn);
      return False;
    }
  } else {
    return False;
  }
}

function _mail_proxy($server,$port,$base,$filter,$attribute,$proxyport) {
  $message = "" ;
  $proxyhost = _ldapsearch($server,$port,$base,$filter,$attribute);

  if ( $proxyhost === '' ) {
    // proxyhost is not found
    $message = "proxy=failure" ;
    header('Content-type: text/html');
    header('Auth-Status: Invalid login') ;
  } else {
    // proxyhost is found
    $proxyip = gethostbyname($proxyhost);

    $message = sprintf('proxy=%s:%s', $proxyhost, $proxyport );
    header('Content-type: text/html');
    header('Auth-Status: OK') ;
    header("Auth-Server: $proxyip") ;
    header("Auth-Port: $proxyport") ;
  }
  return $message ;
}

// ldap search
function _ldapsearch($server,$port,$base,$filter,$attribute) {

  $conn = ldap_connect($server, $port);
  if ($conn) {
    ldap_set_option($conn, LDAP_OPT_PROTOCOL_VERSION, 3);
    $sresult = ldap_search($conn, $base, $filter, array($attribute));
    $info = ldap_get_entries($conn, $sresult);
    if ( $info[0][$attribute][0] != "" ) {
      return $info[0][$attribute][0];
    }
  }
  return "" ;
}

// set $env from nginx
$env['meth']    = getenv('HTTP_AUTH_METHOD');
$env['user']    = getenv('HTTP_AUTH_USER');
$env['passwd']  = getenv('HTTP_AUTH_PASS');
$env['salt']    = getenv('HTTP_AUTH_SALT');
$env['proto']   = getenv('HTTP_AUTH_PROTOCOL');
$env['attempt'] = getenv('HTTP_AUTH_LOGIN_ATTEMPT');
$env['client']  = getenv('HTTP_CLIENT_IP');
$env['host']    = getenv('HTTP_CLIENT_HOST');
$env['port']    = getenv('HTTP_PORT');
$env['helo']    = getenv('HTTP_AUTH_SMTP_HELO');
$env['from']    = getenv('HTTP_AUTH_SMTP_FROM');
$env['to']      = getenv('HTTP_AUTH_SMTP_TO');

$log = "" ;

// protocol port map
$portmap = array(
  "smtp" => 25,
  "pop3" => 110,
  "imap" => 143,
);

// port searvice name map
$protomap = array(
  "995" => "pops",
  "993" => "imaps",
  "110" => "pop",
  "143" => "imap",
  "587" => "smtp",
  "465" => "smtps",
);

// ldap setting
$ldap = array(
  "host" => "127.0.0.1",
  "port" => 389,
  "basedn" => "",
  "filter" => "(mailRoutingAddress=" . $env['user'] . ")",
  "attribute" => "mailhost",
  "dn" => "",
  "passwd" => "",
);

// split uid and domain
$spmra = preg_split('/\@/', $env['user']) ;

// make dn
foreach (preg_split("/\./", $spmra[1]) as $value) {
        $ldap['dn'] = $ldap['dn'] . 'dc=' . $value . ',' ;
}
$tmpdn = preg_split('/,$/',$ldap['dn']);
$ldap['dn'] = 'uid=' . $spmra[0] . ',ou=People,' . $tmpdn[0];

// set search attribute
if ( $env['proto'] === 'smtp' ) {
  $ldap['attribute'] = 'sendmailmtahost' ;
}

// set log
$log = sprintf('meth=%s, user=%s, client=%s, proto=%s', $env['meth'], $env['user'], $env['client'], $protomap[$env['port']]);

// set password
$ldap['passwd'] = urldecode($env['passwd']) ;

// ldap authentication
if ( _ldapauth($ldap['host'],$ldap['port'],$ldap['dn'],$ldap['passwd'])) {
  // authentication successful
  $log = sprintf ('auth=successful, %s', $log) ;
  $proxyport = $portmap[$env['proto']];
  $result = _mail_proxy($ldap['host'],$ldap['port'],$ldap['basedn'],$ldap['filter'],$ldap['attribute'],$proxyport);
  $log = sprintf ('%s, %s', $log,$result) ;
} else {
  // authentication failure
  // $log = sprintf('auth=failure, %s, passwd=%s', $log, $ldap['passwd']);
  $log = sprintf('auth=failure, %s', $log);
  header('Content-type: text/html');
  header('Auth-Status: Invalid login') ;
}

_writelog($log);
exit;
?>
_EOL_

#-- nginx, php-fpm の起動
systemctl enable nginx php73-php-fpm
systemctl start nginx php73-php-fpm

#-- firewall の設定
firewall-cmd --permanent --add-port={25,587,465,993,995,443}/tcp
firewall-cmd --reload
