#!/bin/bash
#
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトは Mattermost をセットアップします
# (このスクリプトは CentOS7.Xでのみ動作します)
#
# 事前作業として以下の2つが必要となります
# ・さくらのクラウドDNSにゾーン登録を完了していること
# ・さくらのクラウドAPIのアクセストークンを取得していること
# ブラウザからアクセスできるようになるまでに10分程度のお時間がかかります
# セットアップ完了後、サーバを自動で再起動します
# https://(ドメイン)
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-7
# @sacloud-text required ZONE "さくらのクラウドDNSで管理しているDNSゾーン" ex="example.com"
# @sacloud-text SUB "ドメイン(DNSゾーン名が含まれている必要があります。入力しない場合はDNSゾーン名で登録します)" ex="mattermost.example.com"
# @sacloud-apikey required permission=create AK "APIキー"

_motd() {
	case $1 in
		start)
			echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the log file: $2\n" >> /etc/motd
		;;
		fail)
			echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the log file: ${2}\n" > /etc/motd
			exit 1
		;;
		end)
			cp -f /dev/null /etc/motd
		;;
	esac
}

KEY="${SACLOUD_APIKEY_ACCESS_TOKEN}:${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}"
LOG="$(pwd)/$(basename $0).log"

# セットアップ中のmotdに変更
_motd start ${LOG}

set -x
source /etc/sysconfig/network-scripts/ifcfg-eth0
ZONE="@@@ZONE@@@"
DOMAIN="@@@SUB@@@"
NAME="@"

# ドメイン入力チェック
if [ -n "${DOMAIN}" ]
then
	if [ $(echo ${DOMAIN} | grep -c "\.${ZONE}$") -ne 1 ]
	then
		echo "ドメインにゾーンが含まれていません"
		_motd fail ${LOG}
	fi
	NAME=$(echo ${DOMAIN} | sed "s/\.${ZONE}$//")
else
	DOMAIN=${ZONE}
fi

# リポジトリの設定
yum install -y yum-utils
yum-config-manager --enable epel
yum remove -y mysql-community-release
yum localinstall -y https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm

# パッケージのアップデートとインストール
yum update -y
yum install -y bind-utils jq mysql-community-server expect nginx openssl openssl-devel

# DNS 登録
if [ $(dig ${ZONE} ns +short | egrep -c '^ns[0-9]+.gslb[0-9]+.sakura.ne.jp.$') -ne 2 ]
then
	echo "お客様ドメインのNSレコードにさくらのクラウドDNSが設定されておりません"
	_motd fail ${LOG}
fi

for x in A MX TXT
do
	if [ $(dig ${DOMAIN} ${x} +short | grep -vc "^$") -ne 0 ]
	then
		echo "${x}レコードが既に登録されています"
		_motd fail ${LOG}
	fi
done

CZONE=$(jq -r ".Zone.Name" /root/.sacloud-api/server.json)
BASE=https://secure.sakura.ad.jp/cloud/zone/${CZONE}/api/cloud/1.1
API=${BASE}/commonserviceitem/
RESJS=resource.json
ADDJS=add.json
UPJS=update.json
RESTXT=response.txt

set +x
curl -s -v --user "${KEY}" ${API} 2>${RESTXT} | jq -r ".CommonServiceItems[] | select(.Status.Zone == \"${ZONE}\")" > ${RESJS} 
set -x
if [ $(grep -c "^< Status: 200 OK" ${RESTXT}) -ne 1 ]
then
	echo "APIへのアクセスが失敗しました"
	_motd fail ${LOG}
fi
rm -f ${RESTXT}

RESID=$(jq -r .ID ${RESJS})
API=${API}${RESID}
RECODES=$(jq -r ".Settings.DNS.ResourceRecordSets" ${RESJS})
if [ $(echo "${RECODES}" | grep -c "^\[\]$") -ne 1 ]
then
	if [ -n "${RECODES}" ]
	then
		if [ "${DOMAIN}" = "${ZONE}" ]
		then
			echo "レコードを登録していないドメインを指定してください"
			_motd fail ${LOG}
		fi
	else
		echo "リソースIDが取得できません、APIキーとドメインを確認してください"
		_motd fail ${LOG}
	fi
fi

cat <<_EOF_> ${ADDJS}
[
	{ "Name": "${NAME}", "Type": "A", "RData": "${IPADDR}" },
	{ "Name": "${NAME}", "Type": "MX", "RData": "10 ${DOMAIN}." },
	{ "Name": "${NAME}", "Type": "TXT", "RData": "v=spf1 +ip4:${IPADDR} -all" }
]
_EOF_
DNSREC=$(echo "${RECODES}" | jq -r ".+$(cat ${ADDJS})")

cat <<_EOF_> ${UPJS}
{
	"CommonServiceItem": {
		"Settings": {
			"DNS":  {
				"ResourceRecordSets": $(echo ${DNSREC})
			}
		}
	}
}
_EOF_

set +x
curl -s --user -v "${KEY}" -X PUT -d "$(cat ${UPJS} | jq -c .)" ${API} 2>${RESTXT} | jq "."
set -x
if [ $(grep -c "^< Status: 200 OK" ${RESTXT}) -ne 1 ]
then
	echo "APIへのアクセスが失敗しました"
	_motd fail ${LOG}
fi
rm -f ${RESTXT}

# Mysql
cat <<_EOF_>> /etc/my.cnf

character-set-server = utf8mb4
innodb_large_prefix = ON
innodb_file_format = Barracuda
innodb_file_format_max = Barracuda

[mysql]
default-character-set = utf8mb4
_EOF_

systemctl enable mysqld
systemctl start mysqld

TMPPASS="$(awk '/temporary password/{print $NF}' /var/log/mysqld.log)"
PASSWORD="$(mkpasswd -l 11 -d 3 -c 3 -C 3 -s 0)"
mysqladmin -u root -p${TMPPASS} password "${PASSWORD}!"

cat <<_EOF_> /root/.my.cnf
[client]
host     = localhost
user     = root
password = ${PASSWORD}!
socket   = /var/lib/mysql/mysql.sock
_EOF_
chmod 600 /root/.my.cnf
export HOME=/root

mysql -e "SET GLOBAL validate_password_policy=LOW;" ;
mysql -e "SET GLOBAL validate_password_length=7;"

# mattermost
VERSION=3.10.0
curl -O https://releases.mattermost.com/${VERSION}/mattermost-team-${VERSION}-linux-amd64.tar.gz
tar xpf mattermost-team-${VERSION}-linux-amd64.tar.gz
mv mattermost /opt/
mkdir -p /opt/mattermost/data
adduser mattermost
chown -R mattermost. /opt/mattermost
chmod -R g+w /opt/mattermost
mysql -e "create database mattermost character set utf8 collate utf8_bin;"
mysql -e "GRANT ALL PRIVILEGES ON mattermost.* TO 'mmuser'@'localhost' IDENTIFIED BY 'mostest' ;"
mysql -e "FLUSH PRIVILEGES;"

sed -i -e 's/dockerhost/127.0.0.1/' \
-e 's/mattermost_test/mattermost/' \
-e "s#SiteURL.*#SiteURL\": \"https://${DOMAIN}\",#" \
-e 's/SendEmailNotifications.*/SendEmailNotifications": true,/' \
-e 's/FeedbackName.*/FeedbackName": "Mattermost",/' \
-e "s/FeedbackEmail.*/FeedbackEmail\": \"mattermost@${DOMAIN}\",/" \
-e 's/RequireEmailVerification.*/RequireEmailVerification\": true,/' \
-e 's/SMTPServer.*/SMTPServer": "127.0.0.1",/' \
-e 's/SMTPPort.*/SMTPPort": "25",/' \
-e 's/"en"/"ja"/' /opt/mattermost/config/config.json

cat <<_EOF_> /etc/systemd/system/mattermost.service
[Unit]
Description=Mattermost
After=syslog.target network.target mysqld.service

[Service]
Type=simple
WorkingDirectory=/opt/mattermost/bin
User=mattermost
ExecStart=/opt/mattermost/bin/platform
PIDFile=/var/spool/mattermost/pid/master.pid
LimitNOFILE=49152

[Install]
WantedBy=multi-user.target
_EOF_

systemctl enable mattermost.service
systemctl start mattermost

# nginx
sed -i '1,/location/s/location \/ {/location ^~ \/.well-known\/acme-challenge\/ {}\n\tlocation \/ {\n\t\treturn 301 https:\/\/$host$request_uri;/' /etc/nginx/nginx.conf
chown -R nginx. /usr/share/nginx/html

cat <<_EOF_> /etc/nginx/conf.d/mattermost.conf
upstream backend {
	server 127.0.0.1:8065;
}

proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=mattermost_cache:10m max_size=3g inactive=120m use_temp_path=off;

server {
	listen 443 ssl http2 default_server;
	server_name ${DOMAIN};

	ssl_protocols TLSv1.2;
	ssl_ciphers EECDH+AESGCM:EECDH+AES;
	ssl_ecdh_curve prime256v1;
	ssl_prefer_server_ciphers on;
	ssl_session_cache shared:SSL:10m;
	ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

	index index.html;
	server_tokens off;
	charset utf-8;

	location ~ /api/v[0-9]+/(users/)?websocket\$ {
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		client_max_body_size 50M;
		proxy_set_header Host \$http_host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto \$scheme;
		proxy_set_header X-Frame-Options SAMEORIGIN;
		proxy_buffers 256 16k;
		proxy_buffer_size 16k;
		proxy_read_timeout 600s;
		proxy_pass http://backend;
	}

	location / {
		client_max_body_size 50M;
		proxy_set_header Connection "";
		proxy_set_header Host \$http_host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto \$scheme;
		proxy_set_header X-Frame-Options SAMEORIGIN;
		proxy_buffers 256 16k;
		proxy_buffer_size 16k;
		proxy_read_timeout 600s;
		proxy_cache mattermost_cache;
		proxy_cache_revalidate on;
		proxy_cache_min_uses 2;
		proxy_cache_use_stale timeout;
		proxy_cache_lock on;
		proxy_pass http://backend;
	}
}
_EOF_

# postfix
cat <<_EOL_>> /etc/postfix/main.cf
myhostname = ${DOMAIN}
smtpd_helo_required = yes
smtpd_hard_error_limit = 5
smtp_tls_CAfile = /etc/pki/tls/certs/ca-bundle.crt
smtp_tls_security_level = may
smtp_tls_loglevel = 1
anvil_rate_time_unit = 60s
smtpd_client_connection_count_limit = 20
smtpd_client_message_rate_limit = 20
smtpd_client_recipient_rate_limit = 20
disable_vrfy_command = yes
smtpd_discard_ehlo_keywords = dsn, enhancedstatuscodes, etrn
_EOL_
sed -i -e 's/^inet_interfaces.*/inet_interfaces = all/' -e 's/^inet_protocols = all/inet_protocols = ipv4/' /etc/postfix/main.cf

systemctl restart postfix

# firewall
firewall-cmd --permanent --add-port=25/tcp --add-port=80/tcp --add-port=443/tcp
firewall-cmd --reload

# Lets Encrypt
cd /usr/local
git clone https://github.com/certbot/certbot
export PATH=/usr/local/certbot:${PATH}
CERT=/etc/letsencrypt/live/${DOMAIN}/fullchain.pem
CA=$(certbot-auto -n certonly --standalone -d ${DOMAIN} -m root@${DOMAIN} --agree-tos)
${CA}
for x in $(seq 1 3)
do
	if [ ! -f ${CERT} ]
	then
		${CA}
		sleep 300
	fi
done

if [ ! -f ${CERT} ]
then
	echo "証明書の取得に失敗しました"
	_motd fail ${LOG}
fi

echo "$((${RANDOM}%60)) $((${RANDOM}%24)) * * $((${RANDOM}%7)) root /usr/local/certbot/certbot-auto renew --webroot -w /usr/share/nginx/html --post-hook 'systemctl reload nginx'" > /etc/cron.d/certbot-auto

systemctl enable nginx
systemctl start nginx

# fulltext search
mysql mattermost -u mmuser -pmostest -e "ALTER TABLE Posts DROP INDEX idx_posts_message_txt;"
mysql mattermost -u mmuser -pmostest -e "ALTER TABLE Posts ADD FULLTEXT INDEX idx_posts_message_txt (\`Message\`) WITH PARSER ngram COMMENT 'ngram reindex';"

# PTR 登録
API=${BASE}/ipaddress/${IPADDR}
cd /root/.sacloud-api/notes
PTRJS=ptr.json
cat <<_EOF_> ${PTRJS}
{
 "IPAddress": { "HostName": "${DOMAIN}" }
}
_EOF_
set +x
curl -s --user "${KEY}" -X PUT -d "$(cat ${PTRJS} | jq -c .)" ${API} |jq "."
PRET=$(curl -s --user "${KEY}" -X GET ${API} | jq -r "select(.IPAddress.HostName == \"${DOMAIN}\") | .is_ok")
set -x

if [ "${PRET}x" != "truex" ]
then
	echo "逆引きの登録に失敗しました"
	_motd fail ${LOG}
fi

# reboot
shutdown -r 1

echo "セットアップが完了しました"

_motd end
