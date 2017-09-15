#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

cat <<_EOL_>/etc/yum.repos.d/MariaDB.repo
# MariaDB 10.1 CentOS repository list - created 2016-12-26 05:08 UTC
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
_EOL_

yum install -y MariaDB-server MariaDB-client

sed -i "s/^#bind-address=0.0.0.0/bind-address=127.0.0.1/" /etc/my.cnf.d/server.cnf
systemctl enable mariadb
systemctl start mariadb

mysqladmin -u root password "${ROOT_PASSWORD}"

cat <<_EOL_> /root/.my.cnf
[client]
host     = localhost
user     = root
password = ${ROOT_PASSWORD}
socket   = /var/lib/mysql/mysql.sock
_EOL_
chmod 600 /root/.my.cnf
export HOME=/root

mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1');"
mysql -e "DROP DATABASE test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

