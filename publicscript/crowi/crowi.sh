#!/bin/bash
# @sacloud-once
#
# @sacloud-require-archive distro-ubuntu distro-ver-16.04.*
#
# @sacloud-desc-begin
#   Markdown形式で記述可能な組織用コミュニケーションツールCrowiをセットアップするスクリプトです。
#   サーバ作成後はブラウザより「http://サーバのIPアドレス/installer」にアクセスすることで設定が行えます。
#   （このスクリプトは、16.04 でのみ動作します）
#   APIキーとさくらのクラウドDNSで管理しているゾーンがあれば、
#   DNSのAレコードとLets EncryptのSSL証明書の設定までセットアップします。
# @sacloud-desc-end
#
# @sacloud-apikey permission=create AK "APIキー(DNSと、Lets Encryptの証明書をセットアップします)"
# @sacloud-text ZONE "さくらのクラウドDNSで管理しているDNSゾーン(APIキー必須)" ex="example.com"
# @sacloud-text SUB "ドメイン(DNSゾーン名が含まれている必要があります。空の場合はDNSゾーン名でセットアップします)" ex="crowi.example.com"
#
#---------UPDATE /etc/motd----------#
_motd() {
	log=$(ls /root/.sacloud-api/notes/*log)
	motsh=/etc/update-motd.d/99-startup
	status=/tmp/startup.status
	echo "#!/bin/bash" > ${motsh}
	echo "cat $status" >> ${motsh}
	chmod 755 ${motsh}

	case $1 in
	start)
		echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the logfile: ${log}\n" > ${status}
	;;
	fail)
		echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the logfile: ${log}\n" > ${status}
		exit 1
	;;
	end)
		rm -f ${motsh}
	;;
	esac
}

KEY="${SACLOUD_APIKEY_ACCESS_TOKEN}:${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}"
SSL=1
if [ "${KEY}" = ":" ]
then
	SSL=0
fi

set -e
trap '_motd fail' ERR

_motd start
apt install -y curl jq

IPADDR=$(awk '/^address/{print $2}' /etc/network/interfaces)
if [ ${SSL} -eq 1 ]
then
	ZONE="@@@ZONE@@@"
	DOMAIN="@@@SUB@@@"
	NAME="@"

	if [ -n "${DOMAIN}" ]
	then
		if [ $(echo ${DOMAIN} | grep -c "\.${ZONE}$") -eq 1 ]
		then
			NAME=$(echo ${DOMAIN} | sed "s/\.${ZONE}$//")
		elif [ "${DOMAIN}" != "${ZONE}" ]
		then
			echo "The Domain is not included in your Zone"
			_motd fail
		fi
	else
		DOMAIN=${ZONE}
	fi

	if [ $(dig ${ZONE} ns +short | egrep -c '^ns[0-9]+.gslb[0-9]+.sakura.ne.jp.$') -ne 2 ]
	then
		echo "対象ゾーンのNSレコードにさくらのクラウドDNSが設定されておりません"
		_motd fail
	fi

	if [ $(dig ${DOMAIN} A +short | grep -vc "^$") -ne 0 ]
	then
		echo "${DOMAIN}のAレコードが登録されています"
		_motd fail
	fi

	CZONE=$(jq -r ".Zone.Name" /root/.sacloud-api/server.json)
	BASE=https://secure.sakura.ad.jp/cloud/zone/${CZONE}/api/cloud/1.1
	API=${BASE}/commonserviceitem/
	RESJS=resource.json
	ADDJS=add.json
	UPDATEJS=update.json
	RESTXT=response.txt
	# api connect check
	curl -s -v --user "${KEY}" ${API} 2>${RESTXT} | jq -r ".CommonServiceItems[] | select(.Status.Zone == \"${ZONE}\")" > ${RESJS}
	if [ $(grep -c "^< Status: 200 OK" ${RESTXT}) -ne 1 ]
	then
		echo "API connect error"
		_motd fail
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
				_motd fail
			fi
		else
			echo "ドメインのリソースIDが取得できません"
			_motd fail
		fi
	fi

cat <<_EOF_> ${ADDJS}
[
	{ "Name": "${NAME}", "Type": "A", "RData": "${IPADDR}" }
]
_EOF_

	DNSREC=$(echo "${RECODES}" | jq -r ".+$(cat ${ADDJS})")

cat <<_EOF_> ${UPDATEJS}
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
	curl -s -v --user "${KEY}" -X PUT -d "$(cat ${UPDATEJS} | jq -c .)" ${API} 2>${RESTXT} | jq "."
	if [ $(grep -c "^< Status: 200 OK" ${RESTXT}) -ne 1 ]
	then
		echo "API connect error"
		_motd fail
	fi
	rm -f ${RESTXT}
fi

# package update
apt update

# install nodejs
curl -sL https://deb.nodesource.com/setup_6.x -o nodesource_setup.sh
bash nodesource_setup.sh
apt install -y nodejs

npm install -g npm

# install MongoDB
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
apt update
apt install -y mongodb-org

cat << EOF >> /etc/systemd/system/mongodb.service
[Unit]
Description=MongoDB Database Service
Wants=network.target
After=network.target

[Service]
ExecStart=/usr/bin/mongod --config /etc/mongod.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
User=mongodb
Group=mongodb
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF

systemctl status mongodb.service >/dev/null 2>&1 || systemctl start mongodb.service
for i in {1..5}; do
	sleep 1
	systemctl status mongodb.service && break
	[ "$i" -lt 5 ] || exit 1
done
systemctl enable mongodb.service

apt install -y pwgen
PASSWD=$(pwgen -s 32 1)
cat << EOF >> /tmp/mongobat.js
db.createUser({user: "crowi", pwd: "$PASSWD", roles: [{role: "readWrite", db: "crowidb"}]});
EOF
mongo crowidb < /tmp/mongobat.js
rm -rf /tmp/mongobat.js

# install ElasticSerach
apt install -y openjdk-8-jre
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add
echo "deb https://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
apt update
apt install -y elasticsearch
/usr/share/elasticsearch/bin/plugin install analysis-kuromoji

systemctl status elasticsearch.service >/dev/null 2>&1 || systemctl start elasticsearch.service
for i in {1..5}; do
	sleep 1
	systemctl status elasticsearch.service && break
	[ "$i" -lt 5 ] || exit 1
done
systemctl enable elasticsearch.service

# install Crowi
apt install -y git build-essential libkrb5-dev
git clone https://github.com/crowi/crowi.git /opt/crowi
cd /opt/crowi
npm install
npm run build

cat << EOF > /etc/systemd/system/crowi.service
[Unit]
Description=Crowi - The Simple & Powerful Communication Tool Based on Wiki
After=network.target mongodb.service

[Service]
WorkingDirectory=/opt/crowi
EnvironmentFile=/opt/crowi/crowi.conf
# Measures for failure at the first OS restart
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/node app.js

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /opt/crowi/crowi.conf
PASSWORD_SEED="yourpasswordseed"
MONGO_URI="mongodb://crowi:$PASSWD@localhost/crowidb"
FILE_UPLOAD="local"
PORT=3000
ELASTICSEARCH_URI="localhost:9200"
EOF

systemctl status crowi.service >/dev/null 2>&1 || systemctl start crowi.service
for i in {1..5}; do
	sleep 1
	systemctl status crowi.service && break
	[ "$i" -lt 5 ] || exit 1
done
systemctl enable crowi.service

# nginx
apt install -y nginx
systemctl stop nginx.service

if [ ${SSL} -eq 1 ]
then
	HOSTNAME=${DOMAIN}
else
	HOSTNAME="localhost"
fi

NGINX_CONFIGPATH="/etc/nginx/nginx.conf"
mv "$NGINX_CONFIGPATH" "${NGINX_CONFIGPATH}.origin"
cp "/opt/crowi/public/nginx.conf" "$NGINX_CONFIGPATH"
cp "/opt/crowi/public/nginx-mime.types" "/etc/nginx/nginx-mime.types"

sed -i -e "s/\r//g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(^user.*$\)@# \1\nuser       www-data;@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(^error_log.*$\)@# \1\nerror_log  /var/log/nginx/error.log;@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(^pid.*$\)@# \1\npid        /run/nginx.pid;@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(access_log.*access.log.*$\)@# \1\n  access_log   /var/log/nginx/access.log main;@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(listen\s80\sdefault_server;$\)@# \1\n    listen 80 default_server deferred;@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(server_name.*$\)@\1\n    server_name ${HOSTNAME};@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(root\s/sites/example.com/public;$\)@# \1\n    root /opt/crowi/public;\n\n    location / {\n      proxy_pass http://127.0.0.1:3000;\n      proxy_set_header Host \$host;\n      proxy_set_header X-Forwarded-For \$remote_addr;\n    }@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(access_log logs/static.log;$\)@# \1\n      access_log /var/log/nginx/static.log;@g" "$NGINX_CONFIGPATH"

systemctl start nginx.service
systemctl enable nginx.service

ufw allow 22
ufw allow 80

if [ ${SSL} -eq 1 ]
then
	CPATH=/usr/local/certbot
	git clone https://github.com/certbot/certbot ${CPATH}
	WROOT=/opt/crowi/public
	DOMAIN=${DOMAIN}
	${CPATH}/certbot-auto -n certonly --webroot -w ${WROOT} -d ${DOMAIN} -m root@${DOMAIN} --agree-tos

	CERT=/etc/letsencrypt/live/${DOMAIN}/fullchain.pem
	CKEY=/etc/letsencrypt/live/${DOMAIN}/privkey.pem
	sed -i "s/listen 80 default_server deferred/listen 443 ssl http2 default_server deferred/" ${NGINX_CONFIGPATH}
	sed -i "s#server_name ${HOSTNAME};#server_name ${HOSTNAME};\n    ssl_protocols TLSv1.2;\n    ssl_ciphers EECDH+AESGCM:EECDH+AES;\n    ssl_ecdh_curve prime256v1;\n    ssl_prefer_server_ciphers on;\n    ssl_session_cache shared:SSL:10m;\n    ssl_certificate ${CERT};\n    ssl_certificate_key ${CKEY};#" ${NGINX_CONFIGPATH}
	tac ${NGINX_CONFIGPATH} | sed '1,/^}$/ s#^}$#}\n  include /etc/nginx/crowi_http.conf;#' | tac > /tmp/nginx.conf
	mv -f /tmp/nginx.conf ${NGINX_CONFIGPATH}
cat <<_EOF_> /etc/nginx/crowi_http.conf
server {
	listen       80 default_server;
	server_name  ${DOMAIN};
	root         /usr/share/nginx/html;

	location ^~ /.well-known/acme-challenge/ {}
	location / {
		return 301 https://\$host\$request_uri;
	}
}
_EOF_
	ufw allow 443

	systemctl restart nginx.service

	WROOT=/usr/share/nginx/html
	R=${RANDOM}
	echo "$((${R}%60)) $((${R}%24)) * * $((${R}%7)) root ${CPATH}/certbot-auto renew --webroot -w ${WROOT} --post-hook 'systemctl reload nginx'" > /etc/cron.d/certbot-auto

fi

ufw enable

# reboot
shutdown -r 1

_motd end
