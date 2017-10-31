#!/bin/bash
#
# @sacloud-name "Aipo"
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトは オープンソース グループウェア Aipo をセットアップします
# (このスクリプトは CentOS7.Xでのみ動作します)
# URLは http://IPアドレス または http(s)://指定のドメイン名 です
# 初期ユーザとパスワードは admin です
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-7
# @sacloud-apikey permission=create AK "APIキーを選択すると指定したドメインでセットアップします"
# @sacloud-text ZONE "さくらのクラウドDNSで管理しているDNSゾーン" ex="example.com"
# @sacloud-text SUB "ドメイン(DNSゾーン名が含まれている必要があります。空の場合はDNSゾーン名でセットアップします)" ex="aipo.example.com"

_motd() {
	LOG=$(ls /root/.sacloud-api/notes/*log)
	case $1 in
		start)
			echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
		;;
		fail)
			echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
			exit 1
		;;
		end)
			cp -f /dev/null /etc/motd
		;;
	esac
}

KEY="${SACLOUD_APIKEY_ACCESS_TOKEN}:${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}"
TLS=0
if [ "${KEY}" != ":" ]
then
	TLS=1
fi

_motd start
set -ex
trap '_motd fail' ERR

# package install
yum install -y epel-release
yum install -y --enablerepo=epel gcc nmap lsof unzip readline-devel zlib-devel nginx bind-utils jq
yum update -y

HOME=$(pwd)
AIPO=8.1.1
TOMCAT=7.0.82
DOMAIN=_
source /etc/sysconfig/network-scripts/ifcfg-eth0

if [ ${TLS} -eq 1 ]
then
	ZONE="@@@ZONE@@@"
	DOMAIN="@@@SUB@@@"
	NAME="@"

	# 入力確認
	if [ -n "${DOMAIN}" ]
	then
		if [ $(echo ${DOMAIN} | grep -c "\.${ZONE}$") -eq 1 ]
		then
			NAME=$(echo ${DOMAIN} | sed "s/\.${ZONE}$//")
		elif [ "${DOMAIN}" != "${ZONE}" ]
		then
			echo "ドメインにゾーンが含まれていません"
			_motd fail
		fi
	else
		DOMAIN=${ZONE}
	fi

	# DNS 登録
	if [ $(dig ${ZONE} ns +short | egrep -c '^ns[0-9]+.gslb[0-9]+.sakura.ne.jp.$') -ne 2 ]
	then
		echo "${ZONE} はさくらのクラウドDNSで管理していません"
		_motd fail
	fi

	for x in A
	do
		if [ $(dig ${DOMAIN} ${x} +short | grep -vc "^$") -ne 0 ]
		then
			echo "${DOMAIN}の${x}レコードがDNSに登録されています"
			_motd fail
		fi
	done

	SITE=$(jq -r ".Zone.Name" /root/.sacloud-api/server.json)
	BASE=https://secure.sakura.ad.jp/cloud/zone/${SITE}/api/cloud/1.1
	API=${BASE}/commonserviceitem/

	STATUS=status.txt
	RESJS=resource.json
	ADDJS=add.json
	REGIST=regist.json

	set +x
	curl -s -v --user "${KEY}" ${API} 2>${STATUS} | jq -r ".CommonServiceItems[] | select(.Status.Zone == \"${ZONE}\")" > ${RESJS}
	set -x

	RESID=$(jq -r .ID ${RESJS})
	API=${API}${RESID}
	RECODES=$(jq -r ".Settings.DNS.ResourceRecordSets" ${RESJS})
	if [ $(grep -c "^< Status: 200 OK" ${STATUS}) -ne 1 ]
	then
		echo "API接続エラー(1)"
		_motd fail
	fi

	if [ $(echo "${RECODES}" | egrep -c "^(\[\]|null)$") -ne 1 ]
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

	cat <<-_EOL_> ${ADDJS}
	[
		{ "Name": "${NAME}", "Type": "A", "RData": "${IPADDR}" }
	]
	_EOL_

	RRS=$(echo "${RECODES}" | jq -r ".+$(cat ${ADDJS})")

	cat <<-_EOL_> ${REGIST}
	{"CommonServiceItem": {"Settings": {"DNS":  {"ResourceRecordSets": $(echo ${RRS})}}}}
	_EOL_

	set +x
	curl -s -v --user "${KEY}" -X PUT -d "$(cat ${REGIST} | jq -c .)" ${API} 2>${STATUS} | jq "."
	set -x
	if [ $(grep -c "^< Status: 200 OK" ${STATUS}) -ne 1 ]
	then
		echo "API接続エラー(2)"
		_motd fail
	fi
fi

# Aipo install
curl -o aipo-${AIPO}-linux-x64.tar.gz -L "https://ja.osdn.net/projects/aipo/downloads/64847/aipo-${AIPO}-linux-x64.tar.gz/"
tar xpf aipo-${AIPO}-linux-x64.tar.gz && cd aipo-${AIPO}-linux-x64 && sh installer.sh /usr/local/aipo

# systemd setting
cat <<_EOL_> /etc/systemd/system/aipo.service
[Unit]
Description=Groupwear Aipo
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/usr/local/aipo/bin/startup.sh
ExecStop=/usr/local/aipo/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
_EOL_

systemctl enable aipo nginx

sed -i 's/^TOMCAT_PORT=80/TOMCAT_PORT=8080/' /usr/local/aipo/conf/tomcat.conf
sed -i 's/port="80"/port="8080"/' /usr/local/aipo/tomcat/conf/server.xml

cp /etc/nginx/nginx.conf{,.org}
cat /etc/nginx/nginx.conf.org | perl -ne \
'{
  if(/^    }/&&$comment){
    print "#$_";
    $comment = 0;
  } elsif (/^    server/||$comment){
    print "#$_";
    $comment = 1;
  } else {
    print;
  }
}' > /etc/nginx/nginx.conf


if [ ${TLS} -eq 1 ]
then

	sed -i "s/localhost/${DOMAIN}/g" /usr/local/aipo/tomcat/conf/server.xml
	sed -i '133i <Valve className="org.apache.catalina.valves.RemoteIpValve" protocolHeader="x-forwarded-proto"/>' /usr/local/aipo/tomcat/conf/server.xml

cat <<'_EOL_'> /etc/nginx/conf.d/aipo.conf
server {
	listen	80 default_server;
	server_name _;
	root	/usr/share/nginx/html;

	location ^~ /.well-known/acme-challenge/ {}
	location / {
		return 301 https://$host$request_uri;
	}

	error_page 404 /404.html;
		location = /40x.html {
	}

	error_page 500 502 503 504 /50x.html;
		location = /50x.html {
	}
}
_EOL_

	sed -i 's/^##//' /etc/nginx/conf.d/aipo.conf

	LD=/etc/letsencrypt/live/${DOMAIN}
	CERT=${LD}/fullchain.pem
	PKEY=${LD}/privkey.pem

	cat <<-_EOL_> /etc/nginx/default.d/ssl.conf
	ssl_protocols TLSv1.2;
	ssl_ciphers EECDH+AESGCM:EECDH+AES;
	ssl_ecdh_curve prime256v1;
	ssl_prefer_server_ciphers on;
	ssl_session_cache shared:SSL:10m;
	ssl_certificate ${CERT};
	ssl_certificate_key ${PKEY};
	_EOL_

	systemctl start nginx

	# firewall
	firewall-cmd --permanent --add-port=80/tcp --add-port=443/tcp
	firewall-cmd --reload

	# Lets Encrypt
	CPATH=/usr/local/certbot
	git clone https://github.com/certbot/certbot ${CPATH}
	WROOT=/usr/share/nginx/html
	CA="${CPATH}/certbot-auto -n certonly --webroot -w ${WROOT} -d ${DOMAIN} -m root@${DOMAIN} --agree-tos"

	for x in 1 2 3 4 5
	do
		${CA} || sleep 180
		if [ -f ${CERT} ]
		then
			break
		elif [ ${x} -eq 4 ]
		then
			echo "証明書の取得に失敗しました"
			_motd fail
		fi
	done

	systemctl stop nginx

	R=${RANDOM}
    echo "$((${R}%60)) $((${R}%24)) * * $((${R}%7)) root ${CPATH}/certbot-auto renew --webroot -w ${WROOT} --post-hook 'systemctl reload nginx'" > /etc/cron.d/certbot-auto

fi

cat <<'_EOL_'>> /etc/nginx/conf.d/aipo.conf
map $http_upgrade $connection_upgrade {
	default upgrade;
	'' close;
}

server {
#	listen 80;
##	listen 443 ssl ;
	server_name _;
	root /usr/local/aipo/tomcat/webapps/ROOT/;

##	include /etc/nginx/default.d/ssl.conf;

	index index.html;
	server_tokens off;
	charset utf-8;

	location ~ "^(/themes/|/images/|/javascript/)" {
		root /usr/local/aipo/tomcat/webapps/ROOT/;
	}

	location / {
		try_files $uri @aipo;
	}

	location /push/ {
		try_files $uri @push;
	}

	location @aipo {
		proxy_pass http://127.0.0.1:8080;
		proxy_set_header Host $host;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
		proxy_set_header X-Forwarded-Host $http_host;
		proxy_set_header X-Forwarded-Server $host;
		proxy_connect_timeout 90;
		proxy_send_timeout 90;
		proxy_read_timeout 90;
		proxy_buffers 4 32k;
		client_max_body_size 8m;
		client_body_buffer_size 128k;
##		proxy_redirect http:// https://;
	}

	location @push {
		proxy_pass http://127.0.0.1:8080;
		proxy_http_version 1.1;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection $connection_upgrade;
		proxy_set_header Host $host;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
		proxy_set_header X-Forwarded-Host $http_host;
		proxy_set_header X-Forwarded-Server $host;
		proxy_connect_timeout 90;
		proxy_send_timeout 86400;
		proxy_read_timeout 86400;
		proxy_buffers 4 32k;
		client_max_body_size 8m;
		client_body_buffer_size 128k;
##		proxy_redirect http:// https://;
	}
}
_EOL_

if [ $TLS -eq 1 ]
then
	sed -i -e 's/^##//' -e 's/^#.*//' /etc/nginx/conf.d/aipo.conf

	# PTR 登録
	API=${BASE}/ipaddress/${IPADDR}
	cd /root/.sacloud-api/notes
	PTRJS=ptr.json

	cat <<-_EOL_> ${PTRJS}
	{"IPAddress": { "HostName": "${DOMAIN}" }}
	_EOL_

	for x in $(seq 1 5)
	do
		if [ "${PRET}x" != "truex" ]
		then
			sleep 60
			set +x
			curl -s --user "${KEY}" -X PUT -d "$(cat ${PTRJS} | jq -c .)" ${API} |jq "."
			PRET=$(curl -s --user "${KEY}" -X GET ${API} | jq -r "select(.IPAddress.HostName == \"${DOMAIN}\") | .is_ok")
			set -x
		fi
	done
else
	sed -i -e 's/^##.*//' -e 's/^#//' /etc/nginx/conf.d/aipo.conf
	firewall-cmd --permanent --add-port=80/tcp
	firewall-cmd --reload
fi

sed -i "s/server_name _/server_name ${DOMAIN}/" /etc/nginx/conf.d/aipo.conf

# update tomcat
cd
curl -L -O http://www-us.apache.org/dist/tomcat/tomcat-7/v${TOMCAT}/bin/apache-tomcat-${TOMCAT}.tar.gz
mv /usr/local/aipo/tomcat /usr/local/aipo/tomcat.org
cd /usr/local/aipo && tar xpf ~/apache-tomcat-${TOMCAT}.tar.gz && mv apache-tomcat-${TOMCAT} tomcat
\cp -fr tomcat.org/{webapps,data,datasource} tomcat
\cp -fp tomcat.org/lib/postgresql-9.3-1103.jdbc41.jar tomcat/lib
\cp -fp tomcat.org/conf/{server.xml,web.xml,catalina.properties} tomcat/conf/

systemctl start aipo nginx

sleep 5

if [ $TLS -eq 1 ]
then
    curl https://${DOMAIN} >/dev/null 2>&1 &
else
    curl http://${IPADDR} >/dev/null 2>&1 &
fi

_motd end
