#!/bin/bash
# @sacloud-once
# @sacloud-desc このスクリプトはHatohol Serverをセットアップします。(このスクリプトは、CentOS7.Xでのみ動作します。)
# @sacloud-desc Hatohol のURLは http://IP Address/hatohol です。
#
# @sacloud-textarea heredoc ADDR "hatoholに登録するZabbixサーバのIPアドレスを1行に1IP入力してください。" ex="127.0.0.1"
# @sacloud-password HP "Hatohol WebのAdminアカウントのパスワード変更"
# @sacloud-text integer min=1024 max=65534 HPORT "httpdのport番号変更(1024以上、65534以下を指定してください)"
# @sacloud-require-archive distro-centos distro-ver-7
#---------SET sacloud values---------#
HATOHOL_PASSWD=@@@HP@@@
HTTPD_PORT=@@@HPORT@@@

#---------Read Value---------#
#ZBX_IPADDR(:ZBX_HTTP_PORT:ZBX_Admin_PASSWD)
IPLIST=/tmp/ip.list
cat > ${IPLIST} @@@ADDR@@@
#---------START OF mysql-server---------#
yum -y install expect mariadb-server
systemctl enable mariadb
systemctl start mariadb

PASSWD=$(mkpasswd -l 12 -d 3 -c 3 -C 3 -s 0)
mysqladmin -u root password "${PASSWD}"

cat <<_EOL_> /root/.my.cnf
[client]
host     = localhost
user     = root
password = ${PASSWD}
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
#---------START OF hatohol-server---------#
curl -o /etc/yum.repos.d/hatohol-el7.repo http://project-hatohol.github.io/repo/hatohol-el7.repo
yum -y install --enablerepo=epel hatohol-server hatohol-web rabbitmq-server hatohol-hap2-zabbix jq

hatohol-db-initiator --db-user root --db-password "${PASSWD}"

mysql -e "create database hatohol_client character set utf8 collate utf8_bin;"
mysql -e "grant all privileges on hatohol_client.* to hatohol@localhost identified by 'hatohol';"
mysql -e "FLUSH PRIVILEGES;"

/usr/libexec/hatohol/client/manage.py syncdb

for x in rabbitmq-server hatohol
do
  systemctl enable ${x}
  systemctl start ${x}
done

rabbitmqctl add_vhost hatohol
rabbitmqctl add_user hatohol hatohol
rabbitmqctl set_permissions -p hatohol hatohol ".*" ".*" ".*"
hatohol-db-initiator --db-user root --db-password "${PASSWD}"

SID=$(curl -s -d 'user=Admin' -d 'password=hatohol' http://localhost:33194/login | jq -r ".sessionId")
UUID=8e632c14-d1f7-11e4-8350-d43d7e3146fb
for DATA in $(egrep "^([0-9]+\.){3}[0-9]+" ${IPLIST})
do
  IPADDR=$(echo ${DATA} | awk -F: '{print $1}')
  PORT=$(echo ${DATA} | awk -F: '{print $2}')
  if [ "${PORT}x" != "x" ]
  then
    IPADDR="${IPADDR}:${PORT}"
  fi
  PASS=$(echo ${DATA} | perl -ne 's/^[0-9\.]+:?([0-9]+)?:?//;print')
  if [ "${PASS}x" = "x" ]
  then
    PASS=zabbix
  fi
  curl -H "X-Hatohol-Session:${SID}" -d "type=7" -d "uuid=${UUID}" -d "nickname=${IPADDR}" -d "pollingInterval=30" -d "retryInterval=10" \
    -d "userName=Admin" -d "password=${PASS}" -d "baseURL=http://${IPADDR}/zabbix/api_jsonrpc.php" -d "passiveMode=false"  -d "tlsEnableVerify=false" \
    -d "brokerUrl=amqp://hatohol:hatohol@127.0.0.1/hatohol" http://localhost:33194/server
done

if [ "${HATOHOL_PASSWD}x" != "x" ]
then
  ADMIN_PASSWD=$(printf ${HATOHOL_PASSWD} | sha256sum | awk '{print $1}')
  mysql -uhatohol -phatohol hatohol -e "update users SET password='${ADMIN_PASSWD}' WHERE name = 'admin';"
fi

rm -f ${IPLIST}
#---------END OF hatohol-server---------#
#---------START OF web-server---------#
if [ $(echo ${HTTPD_PORT} | egrep -c "^[0-9]+$") -eq 1 ] &&  [ ${HTTPD_PORT} -le 65534 ] && [ ${HTTPD_PORT} -ge 1024 ]
then
  sed -i "s/^Listen 80$/Listen ${HTTPD_PORT}/" /etc/httpd/conf/httpd.conf
  sed -i "s/:80/:${HTTPD_PORT}/" /etc/httpd/conf.d/hatohol.conf
  firewall-cmd --permanent --add-port=${HTTPD_PORT}/tcp
else
  firewall-cmd --permanent --add-port=80/tcp
fi

systemctl enable httpd
systemctl start httpd
#---------END OF web-server---------#
#---------START OF firewalld---------#
firewall-cmd --reload
#---------END OF firewalld---------#
#---------START OF message of the day---------#
hatoholmotd(){
  MOTD=$(echo -e "[43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [0m
[43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [0m
[43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [0m
[43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [0m
[43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [47m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [0m
[43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [47m [47m [47m [47m [43m [43m [43m [43m [43m [47m [47m [47m [47m [47m [47m [43m [43m [43m [43m [47m [47m [47m [47m [43m [43m [43m [43m [47m [47m [43m [47m [47m [47m [47m [43m [43m [43m [43m [43m [43m [47m [47m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [0m
[43m [43m [47m [47m [47m [47m [47m [47m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [47m [47m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [47m [47m [43m [43m [0m
[43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [47m [47m [47m [47m [47m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [0m
[43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [0m
[43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [0m
[43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [47m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [47m [47m [43m [43m [0m
[43m [43m [47m [47m [43m [43m [47m [47m [43m [43m [43m [47m [47m [47m [47m [43m [47m [47m [43m [43m [43m [43m [47m [47m [47m [43m [43m [43m [43m [47m [47m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [47m [47m [47m [47m [43m [43m [43m [43m [47m [47m [43m [43m [0m
[43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [0m
[43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [0m
[43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [47m [47m [43m [43m [43m [47m [47m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [0m
[43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [47m [47m [47m [47m [47m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [0m
[43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [43m [0m
[0m" | sed 's/\[/\\e\[/g')
  printf "${MOTD}"
}
hatoholmotd > /etc/motd
#---------END OF message of the day---------#

exit 0