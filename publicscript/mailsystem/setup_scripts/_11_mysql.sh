#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- mysql リポジトリの追加
yum remove -y mysql-community-release
yum install -y https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm

yum install -y mysql-community-devel mysql-community-server

#-- mysql の設定
cp -p /etc/my.cnf{,.org}
cat <<_EOL_>> /etc/my.cnf

character-set-server = utf8mb4
innodb_large_prefix = ON
innodb_file_format = Barracuda
innodb_file_format_max = Barracuda
#validate_password_length=7
#validate_password_policy=LOW

[mysql]
default-character-set = utf8mb4
_EOL_

#-- mysqld の起動
systemctl enable mysqld
systemctl start mysqld

#-- .my.cnf の作成
tmppass="$(awk '/temporary password/{print $NF}' /var/log/mysqld.log)"

cat <<_EOL_> /root/.my.cnf
[client]
host     = localhost
user     = root
password = "${tmppass}"
socket   = /var/lib/mysql/mysql.sock
_EOL_

chmod 600 /root/.my.cnf
export HOME=/root

#-- パスワードポリシーの緩和
mysql --connect-expired-password -e "SET GLOBAL validate_password_policy=LOW;" ;
mysql --connect-expired-password -e "SET GLOBAL validate_password_length=7;"

mysqladmin -u root -p${tmppass} password "${ROOT_PASSWORD}"
sed -i "s/^password.*/password = ${ROOT_PASSWORD}/" ~/.my.cnf

mysql -e "SET GLOBAL validate_password_policy=LOW;" ;
mysql -e "SET GLOBAL validate_password_length=7;"

sed -i 's/^#validate/validate/' /etc/my.cnf

mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1');"
mysql -e "FLUSH PRIVILEGES;"
