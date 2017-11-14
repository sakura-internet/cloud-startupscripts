#!/bin/bash
# @sacloud-once
#
# @sacloud-require-archive distro-centos distro-ver-7.*
#
# @sacloud-desc-begin
#   Nginx, PHP-FPM, MariaDBをインストールします。
#   サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
#   http://サーバのIPアドレス/
#   （このスクリプトは、CentOS7.Xでのみ動作します）
# @sacloud-desc-end
# @sacloud-password shellarg db_password "MariaDBに設定するパスワード”
# @sacloud-select-begin required default=54 php_version "PHP Version"
#  54 "5.4"
#  56 "5.6"
#  70 "7.0"
#  71 "7.1"
# @sacloud-select-end

_motd() {
	LOG=$(ls /root/.sacloud-api/notes/*log)
	case $1 in
		start)
			echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
		;;
		fail)
			echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
			exit 1
		;;
		end)
			cp -f /dev/null /etc/motd
		;;
	esac
}

# ready for startup script
_motd start
set -e
trap '_motd fail' ERR

# Install nginx,mariadb,php
yum -y install yum-utils
yum -y install epel-release
yum-config-manager --enable epel
yum -y install nginx libmcrypt
yum -y install mariadb mariadb-server expect

PHPVERSION=@@@php_version@@@
PHPPACKAGE="php php-devel php-mbstring php-pear php-pdo php-gd php-xml php-mcrypt php-mysql php-fpm"

if [ ! -z "${PHPVERSION}" ]; then
	if [ "${PHPVERSION}" = "54" ]
	then
		yum -y install ${PHPPACKAGE}
	else
		rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
		yum -y install --enablerepo=remi,remi-php${PHPVERSION} ${PHPPACKAGE}
	fi
else
	yum -y install ${PHPPACKAGE}
fi

#firewall
firewall-cmd --add-service=http --permanent --zone=public
firewall-cmd --reload

#nginx conf file edit
patch -u /etc/nginx/nginx.conf <<'_EOL_'
+++ /etc/nginx/nginx.conf	2017-11-13 18:47:57.596866533 +0900
--- /etc/nginx/nginx.conf.org	2017-09-18 18:20:24.000000000 +0900
@@ -40,6 +40,7 @@
         listen       [::]:80 default_server;
         server_name  _;
         root         /usr/share/nginx/html;
+        index        index.html index.php;

         # Load configuration files for the default server block.
         include /etc/nginx/default.d/*.conf;
@@ -47,6 +48,13 @@
         location / {
         }

+        location ~ \.php$ {
+            fastcgi_pass 127.0.0.1:9000;
+            fastcgi_index index.php;
+            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
+            include fastcgi_params;
+        }
+
         error_page 404 /404.html;
             location = /40x.html {
         }
_EOL_

sed -i.org '/^[user|group]/s/apache/nginx/' /etc/php-fpm.d/www.conf
chown -R nginx. /var/lib/php /var/log/php-fpm
chmod 700 /var/log/php-fpm

#Start services
systemctl enable mariadb php-fpm nginx
systemctl start mariadb php-fpm nginx

#MySQL initalization
PASSWD=@@@db_password@@@

if [ -z "$PASSWD" ]; then
	PASSWD=$(mkpasswd -l 12 -d 3 -c 3 -C 3 -s 0)
fi
mysql -u root -e "SET PASSWORD FOR root@localhost=PASSWORD('${PASSWD}');"

cat <<_EOL_> /root/.my.cnf
[client]
host     = localhost
user     = root
password = ${PASSWD}
socket   = /var/lib/mysql/mysql.sock
_EOL_
chmod 600 /root/.my.cnf
export HOME=/root

mysql -u root -e "SET PASSWORD FOR root@\"${HOSTNAME}\"=PASSWORD('${PASSWD}');"
mysql -u root -e "SET PASSWORD FOR root@127.0.0.1=PASSWORD('${PASSWD}');"
mysql -u root -e "SET PASSWORD FOR root@\"::1\"=PASSWORD('${PASSWD}');"

mysql -u root -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -e "DROP DATABASE test;"
mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -u root -e "FLUSH PRIVILEGES;"

_motd end
