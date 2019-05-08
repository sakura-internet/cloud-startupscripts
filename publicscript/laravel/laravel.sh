#!/bin/bash
#
# @sacloud-once
# @sacloud-name Laravel
# @sacloud-desc PHP7 Apache MariaDB Composer Laravel をインストールします。
# @sacloud-desc プロジェクトは"/var/www/html/"配下に作成され、
# @sacloud-desc スタートアップスクリプト終了後、ブラウザから80番でアクセス可能です。
# @sacloud-desc MariaDBのパスワードは自動生成され、"/root/.my.cnf"で確認可能です。
#
# @sacloud-require-archive distro-centos distro-ver-7.*


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

_motd start
set -ex
trap '_motd fail' ERR

# set $HOME
echo "* Set HOME"
HOME="/root"
export HOME

# cd ~
echo "* cd home dir"
cd /root

# PHP インストール
echo "* PHP インストール"
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
yum -y install --enablerepo=remi,remi-php70 php

# 依存関係解消
echo "* PHPの依存関係解消"
yum -y install --enablerepo=epel libmcrypt

# パッケージインストール
echo "* パッケージインストール"
yum -y install --enablerepo=remi,remi-php70 php-opcache php-devel php-mbstring php-mcrypt php-mysqlnd php-xml php-zip

# Apache & MariaDB インストール
echo "* Apache & MariaDBインストール"
yum -y install httpd mariadb mariadb-server expect

# Composer インストール
echo "* Composer インストール"
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Laravel Installer ダウンロード
echo "* Laravel Installer ダウンロード"
composer global require "laravel/installer"

# Laravel Project 作成
echo "* Laravel Project 作成"
rm -rf /var/www/html
composer create-project laravel/laravel /var/www/html --prefer-dist

# Apacheの設定変更
echo "* DocumentRoot 変更"
sed -ie 's/DocumentRoot \"\/var\/www\/html\"/DocumentRoot \"\/var\/www\/html\/public\"/' /etc/httpd/conf/httpd.conf

# ディレクトリのパーミッション変更
echo "* ディレクトリのパーミッション変更"
chmod 777 -R /var/www/html/storage

# Apache & MariaDBの有効化＆スタート
echo "* Apache & MariaDBを有効化＆スタート"
systemctl enable mariadb.service
systemctl start mariadb.service
systemctl enable httpd.service
systemctl start httpd.service

# MariaDB設定
echo "* MariaDB設定"
PASSWORD=`mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2`
mysqladmin -u root password "${PASSWORD}"
echo $PASSWORD
cat <<_EOL_> /root/.my.cnf
[client]
host     = localhost
user     = root
password = ${PASSWORD}
socket   = /var/lib/mysql/mysql.sock
_EOL_

# firewallの80番ポート開ける
echo "* firewall で80番ポートを開ける"
firewall-cmd --add-port=80/tcp --zone=public --permanent
firewall-cmd --reload

# 設定完了を表示
echo "* 設定完了"

_motd end

