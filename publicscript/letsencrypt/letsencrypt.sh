#!/bin/bash
#
# @sacloud-name letsencrypt
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトは nginx と certbot-auto をインストールし、入力したドメインでLet's EncryptのTLS証明書を取得します。
# (CentOS7.X でのみ動作します)
#
# 事前作業として以下の2つが必要となります
# ・さくらのクラウドDNSにゾーン登録を完了していること
# ・さくらのクラウドAPIのアクセストークンを取得していること
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-7
# @sacloud-text required ZONE "さくらのクラウドDNSで管理しているDNSゾーン" ex="example.com"
# @sacloud-text DOMAIN "登録ドメイン(DNSゾーン名が含まれている必要があります。空の場合はDNSゾーン名でセットアップします)" ex="www.example.com"
# @sacloud-text required MAILADDRESS "Let's Encryptから連絡を受信するメールアドレス" ex="sakura@example.com"
# @sacloud-apikey required permission=create AK "APIキー"

#===== Startup Script Motd Monitor =====#
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

_check_var() {
	if [ -z $2 ]
	then
		echo "$1 is not defined."
		return 1
	else
		return 0
	fi
}

KEY="${SACLOUD_APIKEY_ACCESS_TOKEN}:${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}"

set -xe
_motd start
set -e
trap '_motd fail' ERR

source /etc/sysconfig/network-scripts/ifcfg-eth0
ZONE=@@@ZONE@@@
DOMAIN=@@@DOMAIN@@@
MADDR=@@@MAILADDRESS@@@
NAME="@"

yum install -y yum-utils
yum-config-manager --enable epel
yum install -y bind-utils jq

# Check input data
_check_var ZONE "${ZONE}"
_check_var MADDR "${MADDR}"

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

if [ $(dig ${ZONE} ns +short | egrep -c "^ns[0-9]+.gslb[0-9]+.sakura.ne.jp.$") -ne 2 ]
then
	echo "${ZONE} はさくらのクラウドDNSで管理していません"
	_motd fail
fi

if [ $(dig ${DOMAIN} A +short | grep -vc "^$") -ne 0 ]
then
	echo "${DOMAIN} の A レコードがDNSに登録されています"
	_motd fail
fi

MDOMAIN=$(echo ${MADDR} | awk -F@ '{print $2}')
if [ $(dig ${MDOMAIN} MX +short | grep -vc "^$") -eq 0 ]
then
	echo "${MDOMAIN} の MX レコードがDNSに登録されていません"
	_motd fail
fi

# DNS registration for your domain names.
SITE=$(jq -r ".Zone.Name" /root/.sacloud-api/server.json)
BASE=https://secure.sakura.ad.jp/cloud/zone/${SITE}/api/cloud/1.1
GETURL=${BASE}/commonserviceitem/

STATUS=status.txt
RESOURCE=resource.json
ADD=add.json
REGIST=regist.json

set +x
if [ "${KEY}x" = "x" ]
then
	echo "API KEYが設定されていません"
	_motd fail
fi

curl -s -v --user "${KEY}" ${GETURL} 2>${STATUS} | jq -r ".CommonServiceItems[] | select(.Status.Zone == \"${ZONE}\")" > ${RESOURCE}
set -x

RESID=$(jq -r .ID ${RESOURCE})
PUTURL=${GETURL}${RESID}
RECODES=$(jq -r ".Settings.DNS.ResourceRecordSets" ${RESOURCE})
if [ $(grep -c "^< Status: 200 OK" ${STATUS}) -ne 1 ]
then
	echo "API接続エラー"
	_motd fail
fi

cat <<-_EOF_> ${ADD}
[
	{ "Name": "${NAME}", "Type": "A", "RData": "${IPADDR}" }
]
_EOF_

RRS=$(echo "${RECODES}" | jq -r ".+$(cat ${ADD})")
cat <<_EOF_> ${REGIST}
{
	"CommonServiceItem": {
		"Settings": {
			"DNS":  {
				"ResourceRecordSets": $(echo ${RRS})
			}
		}
	}
}
_EOF_

set +x
curl -s -v --user "${KEY}" -X PUT -d "$(cat ${REGIST} | jq -c .)" ${PUTURL} 2>${STATUS} | jq "."
set -x

if [ $(grep -c "^< Status: 200 OK" ${STATUS}) -ne 1 ]
then
	echo "API接続エラー"
	_motd fail
fi

# Install nginx
OS_MAJOR_VERSION=$(rpm -q --queryformat '%{VERSION}' centos-release)
ARCH=$(arch)

cat <<_EOF_> /etc/yum.repos.d/nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/${OS_MAJOR_VERSION}/${ARCH}/
gpgcheck=0
enabled=1
_EOF_

yum clean all
yum install nginx -y

# Install cert-bot
CPATH=/usr/local/certbot
git clone https://github.com/certbot/certbot ${CPATH}

# Configure firewall
firewall-cmd --permanent --add-port={80,443}/tcp
firewall-cmd --reload

# Configure nginx
LD=/etc/letsencrypt/live/${DOMAIN}
CERT=${LD}/fullchain.pem
PKEY=${LD}/privkey.pem

cat << _EOF_ > https.conf
server {
	listen 443 ssl http2;
	server_name ${DOMAIN};

	location / {
		root   /usr/share/nginx/html;
		index  index.html index.htm;
	}

	ssl_protocols TLSv1.2;
	ssl_ciphers EECDH+AESGCM:EECDH+AES;
	ssl_ecdh_curve prime256v1;
	ssl_prefer_server_ciphers on;
	ssl_session_cache shared:SSL:10m;

	ssl_certificate ${CERT};
	ssl_certificate_key ${PKEY};

	error_page   500 502 503 504  /50x.html;
	location = /50x.html {
		root   /usr/share/nginx/html;
	}
}
_EOF_

systemctl enable nginx

# Configure Let's Encrypt
WROOT=/usr/share/nginx/html
systemctl start nginx
CA="${CPATH}/certbot-auto -n certonly --webroot -w ${WROOT} -d ${DOMAIN} -m ${MADDR} --agree-tos"

for x in 1 2 3 4
do
	${CA}
	if [ -f ${CERT} ]
	then
		break
	elif [ ${x} -eq 4 ]
	then
		echo "証明書の取得に失敗しました"
		_motd fail
	else
		sleep 300
	fi
done

# Configure SSL Certificate Renewal
mv https.conf /etc/nginx/conf.d/
R=${RANDOM}
echo "$((R%60)) $((R%24)) * * $((R%7)) root ${CPATH}/certbot-auto renew --webroot -w ${WROOT} --post-hook 'systemctl reload nginx'" > /etc/cron.d/certbot-auto

systemctl restart nginx

_motd end

