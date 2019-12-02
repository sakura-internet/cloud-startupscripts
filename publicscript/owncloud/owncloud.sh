#!/bin/bash

# @sacloud-name "owncloud"
# @sacloud-once
#
# @sacloud-desc-begin OwnCloudをセットアップします。
# サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
# http://サーバのIPアドレス/owncloud/
#（このスクリプトは、CentOS7.Xで動作します）
# @sacloud-desc-end
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

yum install -y wget
wget http://download.owncloud.org/download/repositories/production/RHEL_7/ce:stable.repo -O /etc/yum.repos.d/ce:stable.repo
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
yum install -y --enablerepo=remi,remi-php71 php
yum install -y --enablerepo=remi,remi-php71 php-gd php-pdo php-mbstring php-process php-xml php-ldap php-zip php-intl
yum install -y owncloud-files

cat <<'EOT'>/var/www/html/owncloud/config/config.php
<?php
$CONFIG = array (
  'default_language' => 'ja_JP'
);
EOT

chown apache:apache /var/www/html/owncloud/config/config.php

firewall-cmd --add-service=http --zone=public --permanent
firewall-cmd --reload

systemctl enable httpd
systemctl start httpd

_motd end

