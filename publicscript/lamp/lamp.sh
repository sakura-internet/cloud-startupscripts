#!/bin/bash

# @sacloud-name "LAMP"
# @sacloud-once
#
# @sacloud-desc-begin
#   Apache, PHP, MySQLをインストールします。
#   サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
#   http://サーバのIPアドレス/
#   （このスクリプトは、CentOS 7.X, Ubuntu 18.04 で動作します）
# @sacloud-desc-end
# @sacloud-password shellarg mysql_password "MySQLに設定するパスワード(入力がない場合ランダム値がセットされます。)"
# @sacloud-require-archive distro-ubuntu distro-ver-18.04.*
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-tag @simplemode @logo-alphabet-l

PASSWD=@@@mysql_password@@@

if [ -e /etc/redhat-release ]; then
    DIST="redhat"
    DIST_VER=`cat /etc/redhat-release | perl -pe 's/.*release ([0-9.]+) .*/$1/' | cut -d "." -f 1`
else
    if [ -e /etc/lsb-release ]; then
      DIST="lsb"
    fi
fi

if [ $DIST = "redhat" ];then
  if [ $DIST_VER = "7" ];then
    rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm || exit 1
    yum -y install httpd mariadb mariadb-server expect || exit 1
    yum -y install --enablerepo=remi,remi-php70 php php-devel php-mbstring php-pdo php-gd php-mysql || exit 1
    #firewall
    firewall-cmd --add-service=http --permanent --zone=public
    firewall-cmd --add-service=https --permanent --zone=public
    firewall-cmd --reload


    #Start services
    systemctl enable mariadb.service || exit 1
    systemctl start mariadb.service || exit 1


    systemctl enable httpd.service || exit 1
    systemctl start httpd.service || exit 1

    #MySQL initalization
    if [ -z "$PASSWD" ]; then
      PASSWD=$(mkpasswd -l 12 -d 3 -c 3 -C 3 -s 0)
    fi


    export HOME=/root

    mysql -u root -e "SET PASSWORD FOR root@localhost=PASSWORD('${PASSWD}');"
    mysql -u root -p${PASSWD} -e "SET PASSWORD FOR root@\"${HOSTNAME}\"=PASSWORD('${PASSWD}');"
    mysql -u root -p${PASSWD} -e "SET PASSWORD FOR root@127.0.0.1=PASSWORD('${PASSWD}');"
    mysql -u root -p${PASSWD} -e "SET PASSWORD FOR root@\"::1\"=PASSWORD('${PASSWD}');"

    mysql -u root -p${PASSWD} -e "DELETE FROM mysql.user WHERE User='';"
    mysql -u root -p${PASSWD} -e "DROP DATABASE test;"
    mysql -u root -p${PASSWD} -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    mysql -u root -p${PASSWD} -e "FLUSH PRIVILEGES;"

        cat <<_EOL_> /root/.my.cnf
[client]
host     = localhost
user     = root
password = ${PASSWD}
socket   = /var/lib/mysql/mysql.sock
_EOL_
    chmod 600 /root/.my.cnf
  fi
elif [ $DIST = "lsb" ]; then

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -y install apache2 mariadb-server pwgen
    apt-get -y install php libapache2-mod-php php-mysql

    if [ -z "$PASSWD" ]; then
      PASSWD=`pwgen 12 1`
    fi

    mysql -u root -e "SET PASSWORD FOR root@localhost=PASSWORD('${PASSWD}');"

    cat <<_EOL_> /root/.my.cnf
[client]
host     = localhost
user     = root
password = ${PASSWD}
socket   = /var/run/mysqld/mysqld.sock
_EOL_
    chmod 600 /root/.my.cnf
    export HOME=/root


    mysql -e "DELETE FROM mysql.user WHERE User='';"
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1');"
    mysql -e "FLUSH PRIVILEGES;"

   service apache2 restart
fi
