#!/bin/bash

# @sacloud-once
# @sacloud-desc このスクリプトはZabbix Serverをセットアップします。(このスクリプトは、CentOS7.Xでのみ動作します。)
# @sacloud-desc ZabbixのURLは http://IP Address/zabbix です。
#
# @sacloud-select-begin required default=3.2 ZV "Zabbix Version"
#  3.2 "3.2"
#  3.0 "3.0"
#  2.4 "2.4"
#  2.2 "2.2"
# @sacloud-select-end
# @sacloud-password ZP "Zabbix WebのAdminアカウントのパスワード変更"
# @sacloud-text integer min=1024 max=65534 HPORT "httpdのport番号変更(1024以上、65534以下を指定してください)"
# @sacloud-require-archive distro-centos distro-ver-7

#---------SET sacloud values---------#
ZABBIX_VERSION=@@@ZV@@@
ZABBIX_PASSWORD=@@@ZP@@@
HTTPD_PORT=@@@HPORT@@@

#---------START OF mysql-server---------#
yum -y install expect mariadb-server
systemctl enable mariadb
systemctl start mariadb

PASSWORD=$(mkpasswd -l 12 -d 3 -c 3 -C 3 -s 0)
mysqladmin -u root password "${PASSWORD}"

cat <<_EOL_> /root/.my.cnf
[client]
host     = localhost
user     = root
password = ${PASSWORD}
socket   = /var/lib/mysql/mysql.sock
_EOL_
chmod 600 /root/.my.cnf
export HOME=/root

mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1');"
mysql -e "DROP DATABASE test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"
#---------END OF mysql-server---------#
#---------START OF zabbix-server---------#
rpm -ivh http://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/rhel/7/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el7.noarch.rpm
yum -y install zabbix-server zabbix-server-mysql zabbix-web-mysql zabbix-web-japanese zabbix-agent zabbix-get zabbix-sender

mysql -e "create database zabbix character set utf8 collate utf8_bin;"
mysql -e "grant all on zabbix.* to zabbix@localhost identified by 'zabbix';"
mysql -e "FLUSH PRIVILEGES;"

if [ $(echo ${ZABBIX_VERSION} | grep -c "^3") -eq 1 ]
then
  zcat /usr/share/doc/zabbix-server-mysql-${ZABBIX_VERSION}.*/create.sql.gz | mysql -u zabbix -pzabbix zabbix 
else
  cat /usr/share/doc/zabbix-server-mysql-${ZABBIX_VERSION}.*/create/{schema,images,data}.sql | mysql -u zabbix -pzabbix zabbix
fi
sed -i "/^# DBPassword=/a DBPassword=zabbix" /etc/zabbix/zabbix_server.conf

systemctl enable zabbix-server
systemctl start zabbix-server
systemctl enable zabbix-agent
systemctl start zabbix-agent

cat <<'_EOL_'> /etc/zabbix/web/zabbix.conf.php
<?php
// Zabbix GUI configuration file.
global $DB;

$DB['TYPE']     = 'MYSQL';
$DB['SERVER']   = 'localhost';
$DB['PORT']     = '0';
$DB['DATABASE'] = 'zabbix';
$DB['USER']     = 'zabbix';
$DB['PASSWORD'] = 'zabbix';

// Schema name. Used for IBM DB2 and PostgreSQL.
$DB['SCHEMA'] = '';

$ZBX_SERVER      = 'localhost';
$ZBX_SERVER_PORT = '10051';
$ZBX_SERVER_NAME = 'zabbix';

$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
_EOL_

mysql -uzabbix -pzabbix zabbix -e "update hosts set status=0 where host = 'Zabbix server' ;"

if [ "${ZABBIX_PASSWORD}x" != "x" ]
then
  ADMIN_PASSWORD=$(printf ${ZABBIX_PASSWORD} | md5sum | awk '{print $1}')
  mysql -uzabbix -pzabbix zabbix -e "update users SET passwd='${ADMIN_PASSWORD}' WHERE alias = 'Admin';"
fi

firewall-cmd --permanent --add-port=10051/tcp
firewall-cmd --permanent --add-port=10050/tcp
#---------END OF zabbix-server---------#
#---------START OF http-server---------#
sed -i 's/;date\.timezone =/date.timezone = Asia\/Tokyo/' /etc/php.ini
sed -i "s/^post_max_size.*$/post_max_size = 16M/" /etc/php.ini
sed -i "s/^max_execution_time.*$/max_execution_time = 300/" /etc/php.ini
sed -i "s/^max_input_time.*$/max_input_time = 300/" /etc/php.ini

if [ $(echo ${HTTPD_PORT} | egrep -c "^[0-9]+$") -eq 1 ] &&  [ ${HTTPD_PORT} -le 65534 ] && [ ${HTTPD_PORT} -ge 1024 ]
then
  sed -i "s/^Listen 80$/Listen ${HTTPD_PORT}/" /etc/httpd/conf/httpd.conf
  firewall-cmd --permanent --add-port=${HTTPD_PORT}/tcp
else
  firewall-cmd --permanent --add-port=80/tcp
fi

systemctl enable httpd
systemctl start httpd
#---------END OF http-server---------#
#---------START OF firewalld---------#
firewall-cmd --reload
#---------END OF firewalld---------#

exit 0