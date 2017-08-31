#!/bin/bash
# @sacloud-once
# @sacloud-desc OwnCloudをセットアップします。
# @sacloud-desc （このスクリプトは、CentOS6.XもしくはScientific Linux6.Xでのみ動作します）
# @sacloud-require-archive distro-centos distro-ver-6.*
# @sacloud-require-archive distro-sl distro-ver-6.*

#---------START OF iptables---------#
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
wget -O "/etc/yum.repos.d/isv:ownCloud:community.repo" 'http://download.opensuse.org/repositories/isv:ownCloud:community/CentOS_CentOS-6/isv:ownCloud:community.repo'
yum install -y --enablerepo=remi php
yum install -y --enablerepo=remi php-gd php-pdo php-mbstring php-process php-xml php-ldap
yum install -y owncloud
cat <<'EOT'>/var/www/html/owncloud/config/config.php
<?php
$CONFIG = array (
  'default_language' => 'ja_JP'
);
EOT
chown apache:apache /var/www/html/owncloud/config/config.php
service httpd start
chkconfig httpd on

#---------END OF owncloud---------#