#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- mysql のインストール
dnf -y install mysql-{server,devel}

#-- mysqld の起動
systemctl enable mysqld
systemctl start mysqld

(mysqld --initialize-insecure || true)
mysqladmin -u root password "${ROOT_PASSWORD}"

cat <<_EOL_> /root/.my.cnf
[client]
host     = localhost
user     = root
password = "${ROOT_PASSWORD}"
socket   = /var/lib/mysql/mysql.sock
_EOL_

#-- validate_passwordのコンポーネントをインストール
mysql --user=root --password=${ROOT_PASSWORD} -e "INSTALL COMPONENT 'file://component_validate_password';"

cat <<_EOL_>> /etc/my.cnf.d/mysql-server.cnf

default_authentication_plugin=mysql_native_password
default_password_lifetime=0
validate_password.length=4
validate_password.mixed_case_count=0
validate_password.number_count=0
validate_password.special_char_count=0
validate_password.policy=LOW
_EOL_

systemctl restart mysqld
