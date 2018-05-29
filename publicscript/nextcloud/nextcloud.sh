#!/bin/bash
#
# @sacloud-name "Nextcloud"
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトは Nextcloud をセットアップします
# (CentOS7.X でのみ動作します)
# サーバ作成後はブラウザより「http://サーバのIPアドレス/nextcloud/」でアクセスすることができます
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-7

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

# 必要パッケージのインストール
yum update -y
yum install -y epel-release
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
yum install -y httpd php72-php php72-php-{gd,mbstring,mysqlnd,ldap,posix,xml,zip,intl,mcrypt,smbclient,ftp,imap,gmp,apcu,redis,memcached,imagick}

sed -i 's/^;date.timezone =/date.timezone = Asia\/Tokyo/' /etc/opt/remi/php72/php.ini

cd /var/www/html
git clone https://github.com/nextcloud/server.git nextcloud
cd nextcloud
VERSION=$(git tag | egrep -iv "rc|beta" | sed 's/^v//' | sort -n | tail -1)
git checkout v${VERSION}
git submodule update --init
chown -R apache. /var/www/html/nextcloud/

systemctl enable httpd
systemctl start httpd

# Firewall の設定
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload

shutdown -r 1

_motd end
