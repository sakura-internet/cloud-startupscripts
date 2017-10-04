#!/bin/bash

# @sacloud-name "owncloud"
# @sacloud-once
#
# @sacloud-desc-begin OwnCloudをセットアップします。
# サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
# http://サーバのIPアドレス/owncloud/
#（このスクリプトは、CentOS6.X,7.Xで動作します）
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-require-archive distro-centos distro-ver-6.*

set -eux
DIST_VER=`cat /etc/redhat-release | perl -pe 's/.*release ([0-9.]+) .*/$1/' | cut -d "." -f 1`


if [ $DIST_VER = "7" ];then
  yum install -y wget
  wget http://download.owncloud.org/download/repositories/production/CentOS_7/ce:stable.repo -O /etc/yum.repos.d/ce:stable.repo
  yum install -y --enablerepo=remi,remi-php71 php
  yum install -y --enablerepo=remi,remi-php71 php-gd php-pdo php-mbstring php-process php-xml php-ldap php-zip
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
elif [ $DIST_VER = "6" ];then
  cat <<'EOT' > /etc/sysconfig/iptables
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:fail2ban-SSH - [0:0]
-A INPUT -p tcp -m multiport --dports 22 -j fail2ban-SSH
-A INPUT -p TCP -m state --state NEW ! --syn -j DROP
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p udp --sport 123 --dport 123 -j ACCEPT
-A INPUT -p udp --sport 53 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
-A fail2ban-SSH -j RETURN
COMMIT
EOT
  service iptables restart
  #---------END OF iptables---------#
  #---------START OF owncloud---------#
  wget http://download.owncloud.org/download/repositories/production/CentOS_6/ce:stable.repo -O /etc/yum.repos.d/ce:stable.repo
  yum install -y  libwebp --enablerepo=epel
  yum install -y --enablerepo=remi,remi-php56 php
  yum install -y --enablerepo=remi,remi-php56 php-gd php-pdo php-mbstring php-process php-xml php-ldap
  yum install -y owncloud-files
  cat <<'EOT'>/var/www/html/owncloud/config/config.php
<?php
$CONFIG = array (
  'default_language' => 'ja_JP'
);
EOT
  chown apache:apache /var/www/html/owncloud/config/config.php
  service httpd start
  chkconfig httpd on
fi
