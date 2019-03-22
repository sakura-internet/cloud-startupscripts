#!/bin/bash

# @sacloud-name "WordPress for CentOS 7"
# @sacloud-once
#
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-desc-begin
#    WordPressをインストールします。
#    サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
#    http://サーバのIPアドレス/
#    （このスクリプトは、CentOS7.Xで動作します）
# @sacloud-desc-end

# install packages
yum -y install expect httpd httpd-devel mod_ssl php php-devel php-pear mariadb-server php-xml php-mysql php-fpm php-mcrypt|| exit 1
yum -y install php-gd php-mbstring|| exit 1

# init variables
MYSQLPASSWORD=$(mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2)
DBNAME="wp_$(mkpasswd -l 10 -C 0 -s 0)"
DBPASS=$(mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2)
ZIPFILE=$(mktemp)

# set php timezone
cat >/etc/php.d/timezone.ini <<EOL
date.timezone = "Asia/Tokyo"
EOL

# install mysql/mariadb
systemctl start mariadb
for i in {1..5}; do
  sleep 1
  systemctl status mariadb >/dev/null 2>&1 && break
  [ "$i" -lt 5 ] || exit 1
done
systemctl enable mariadb

# init mysql/mariadb
/usr/bin/mysqladmin -u root password "$MYSQLPASSWORD" || exit 1
cat <<EOL > /root/.my.cnf
[client]
host     = localhost
user     = root
password = $MYSQLPASSWORD
socket   = /var/lib/mysql/mysql.sock
EOL
chmod 600 /root/.my.cnf

# init database for WordPress
mysql --defaults-file=/root/.my.cnf <<-EOL
CREATE DATABASE IF NOT EXISTS $DBNAME;
GRANT ALL ON $DBNAME.* TO '$DBNAME'@'localhost' IDENTIFIED BY '$DBPASS';
FLUSH PRIVILEGES;
EOL

# configure WordPress DocumentRoot
cat <<EOL > /etc/httpd/conf.d/$DBNAME.conf
<VirtualHost *:80>
DocumentRoot /var/www/$DBNAME
AllowEncodedSlashes On
<Directory />
    Options FollowSymLinks
    AllowOverride None
</Directory>
<Directory "/var/www/$DBNAME">
    Options FollowSymLinks MultiViews ExecCGI
    AllowOverride All
    Order allow,deny
    allow from all
</Directory>
</VirtualHost>
EOL

# fetch WordPress
curl -L http://ja.wordpress.org/latest-ja.tar.gz | tar zxf - -C /var/www/ || exit 1
mv /var/www/wordpress /var/www/$DBNAME
cat <<EOL > /var/www/$DBNAME/wp-config.php
<?php
/** WordPress のためのデータベース名 */
define('DB_NAME', '$DBNAME');
/** MySQL データベースのユーザー名 */
define('DB_USER', '$DBNAME');
/** MySQL データベースのパスワード */
define('DB_PASSWORD', '$DBPASS');
/** MySQL のホスト名 */
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
\$table_prefix  = 'wp_';
define('WPLANG', 'ja');
define('WP_DEBUG', false);
EOL

curl -L https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/$DBNAME/wp-config.php
cat <<EOL >> /var/www/$DBNAME/wp-config.php
if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
EOL

chown -R apache:apache /var/www/$DBNAME

# start apache processes
systemctl start httpd
for i in {1..5}; do
  sleep 1
  systemctl status httpd >/dev/null 2>&1 && break
  [ "$i" -lt 5 ] || exit 1
done
systemctl enable httpd
systemctl start php-fpm
systemctl enable php-fpm

# set firewalld
firewall-cmd --permanent --add-service http --zone=public
firewall-cmd --reload

# end
