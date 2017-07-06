#!/bin/bash

# @sacloud-once
#
# @sacloud-desc-begin
#   Apache, PHP, MySQLをインストールします。
#   サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
#   http://サーバのIPアドレス/
#   （このスクリプトは、CentOS6.X,7.X,Ubuntu14.04,16.04で動作します）
# @sacloud-desc-end
#@sacloud-radios-begin default=php5 php_version "PHPのバージョン"
#     php5 "5"
#     php7 "7"
# @sacloud-radios-end
# @sacloud-password shellarg mysql_password "MySQLに設定するパスワード(入力がない場合ランダム値がセットされます。)"
# @sacloud-require-archive distro-debian
# @sacloud-require-archive distro-ubuntu
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-require-archive distro-centos distro-ver-6.*

PASSWD=@@@mysql_password@@@
PHP_VERSION=@@@php_version@@@

if [ -e /etc/redhat-release ]; then
    DIST="redhat"
    DIST_VER=`cat /etc/redhat-release | perl -pe 's/.*release ([0-9.]+) .*/$1/' | cut -d "." -f 1`
else
    if [ -e /etc/lsb-release ]; then
      DIST="lsb"
      DIST_VER=`cat /etc/lsb-release | tail -n 1 | cut -d "=" -f 2 | cut -d " " -f 2 | cut -d "." -f 1`
    fi
fi

if [ $DIST = "redhat" ];then
  if [ $DIST_VER = "7" ];then
    if [ $PHP_VERSION = "php7" ];then
      #Install httpd,mariadb,php7
      rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm || exit 1

      yum -y install httpd mariadb mariadb-server expect || exit 1
      yum -y install --enablerepo=remi,remi-php70 php php-devel php-mbstring php-pdo php-gd php-mysql || exit 1
    else
      yum -y install expect mod_php httpd-devel mod_ssl php-devel php-pear mariadb-server php-mbstring php-xml php-gd php-mysql|| exit 1
    fi
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

  elif [ $DIST_VER = "6" ];then

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
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT 
-A INPUT -p udp --sport 123 --dport 123 -j ACCEPT
-A INPUT -p udp --sport 53 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT 
-A fail2ban-SSH -j RETURN
COMMIT
EOT
    service iptables restart
    #---------END OF iptables---------#
    #---------START OF LAMP---------#
    if [ $PHP_VERSION = "php7" ];then
      #Install httpd,mariadb,php7
      yum -y install httpd mysql mysql-server expect || exit 1
      yum -y install libwebp --enablerepo=epel
      yum -y install --enablerepo=remi,remi-php70 php php-devel php-mbstring php-pdo php-gd php-mysql || exit 1
    else
      yum -y install expect httpd-devel mod_ssl php-devel php-pear mysql-server php-mbstring php-xml php-gd php-mysql|| exit 1
    fi
    service httpd status >/dev/null 2>&1 || service httpd start

    for i in {1..5}; do
    sleep 1
    service httpd status && break
    [ "$i" -lt 5 ] || exit 1
    done
    chkconfig httpd on || exit 1

    service mysqld status >/dev/null 2>&1 || service mysqld start
    for i in {1..5}; do
    sleep 1
    service mysqld status && break
    [ "$i" -lt 5 ] || exit 1
    done
    chkconfig mysqld on || exit 1

    if [ -z "$PASSWD" ]; then
        PASSWD=`mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2`
    fi

    /usr/bin/mysqladmin -u root password "$PASSWD" || exit 1

    cat <<EOT > /root/.my.cnf
[client]
host     = localhost
user     = root
password = $PASSWD
socket   = /var/lib/mysql/mysql.sock
EOT
    chmod 600 /root/.my.cnf
    #---------END OF LAMP---------#

  fi
elif [ $DIST = "lsb" ]; then

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -y install apache2 mariadb-server pwgen
    apt-get -y install python-software-properties software-properties-common
    LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y
    apt-get update
    if [ $PHP_VERSION = "php7" ];then
      apt-get -y install php libapache2-mod-php php-mysql
    else
      if [ $DIST_VER = "16" ];then
        apt-get -y install php5.6 php5.6-mysql
      else
        apt-get -y install php5 php5-mysql
      fi
    fi


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
