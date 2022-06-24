#!/bin/bash
# @sacloud-name "code server for Ubuntu"
# @sacloud-once
#
# @sacloud-require-archive distro-ubuntu distro-ver-22.04
# @sacloud-tag @require-core>=1 @require-memory-gib>=2
#
# @sacloud-desc-begin
#   code serverをインストールします。
#   サーバー作成後、Webブラウザでアクセスして下さい。
#
#   ドメインを設定してご利用の場合
#   https://{ドメイン名}/
#
#   サーバーのIPアドレスをご利用の場合（独自ドメイン、TLSを利用しない場合）
#   http://{サーバーのIPアドレス}/
#   ※ローカルネットワークでご利用ください
#
#   補足事項
#   ※ セットアップには5分程度時間がかかります。
#   ※ このスクリプトは、Ubuntu 22.04 でのみ動作します）
#   ※ インストールされるcode-serverは最新版となります。
# @sacloud-desc-end
#
# code server の管理ユーザーの入力フォームの設定
# @sacloud-apikey permission=create AK "APIキー(DNSのAレコードと Let's Encrypt の証明書をセットアップします) (ドメインを設定する場合は必須)"
# @sacloud-text DOMAIN_ZONE "さくらのクラウドDNSで管理しているDNSゾーン名 (ドメインを設定する場合は必須)" ex="example.com"
# @sacloud-text SUBDOMAIN "サブドメイン(未入力の場合はDNSゾーン名でセットアップします。) (ドメインを設定する場合は必須)" ex="code"
# @sacloud-text shellarg maxlen=128 ex=example@sakura.ne.jp EMAIL "Let's Encryptの証明書発行で利用するメールアドレス (ドメインを設定する場合は必須)"
# @sacloud-password required shellarg maxlen=128 ex=test123# PASSWORD "code serverで利用するパスワード"
_motd() {
  LOG=$(ls /root/.sacloud-api/notes/*log)
  case $1 in
  start)
    echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" >/etc/motd
    ;;
  fail)
    echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" >/etc/motd
    exit 1
    ;;
  end)
    cp -f /dev/null /etc/motd
    ;;
  esac
}

set -ex
trap '_motd fail' ERR

_motd start

# parse
DOMAIN_ZONE=@@@DOMAIN_ZONE@@@
SUBDOMAIN=@@@SUBDOMAIN@@@
DOMAIN="${DOMAIN_ZONE}"
if [ -n "${SUBDOMAIN}" ]; then
  DOMAIN="${SUBDOMAIN}.${DOMAIN_ZONE}"
fi
EMAIL=@@@EMAIL@@@
PASSWORD=@@@PASSWORD@@@
# get default user
DEFAULT_USER=$(ls /home)
shopt -s expand_aliases
# update
apt-get -y update
apt-get -y upgrade
# firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
# nginx install and configuration

# check ssl required
KEY="${SACLOUD_APIKEY_ACCESS_TOKEN}:${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}"
SSL=1
if [ "${KEY}" = ":" ]; then
  SSL=0
fi

# exist check
IS_DOMAIN_ZONE=0
if [ -n "${DOMAIN_ZONE}" ]; then
  IS_DOMAIN_ZONE=1
fi

SERVER_NAME=''
if [ "$SSL" = 1 -a "$IS_DOMAIN_ZONE" = 1 ]; then
  SERVER_NAME="server_name $DOMAIN;"
fi

apt-get -y install nginx python3-certbot-nginx
rm /etc/nginx/sites-available/default
rm /etc/nginx/sites-enabled/default
cat <<EOF >/etc/nginx/sites-available/code-server
server {
    listen 80;
    listen [::]:80;
    $SERVER_NAME

    location / {
      proxy_pass http://localhost:8080/;
      proxy_set_header Host \$host;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection upgrade;
      proxy_set_header Accept-Encoding gzip;
    }
}
EOF
ln -s ../sites-available/code-server /etc/nginx/sites-enabled/code-server
systemctl restart nginx
# code-server
latest_tag=$(basename $(curl -sL -o /dev/null -w '%{url_effective}' https://github.com/coder/code-server/releases/latest))
cd /root
curl -LO https://github.com/coder/code-server/releases/download/${latest_tag}/code-server_${latest_tag#v}_amd64.deb
dpkg -i code-server_${latest_tag#v}_amd64.deb
## Config generate
mkdir -p /home/$DEFAULT_USER/.config/code-server
cat <<EOF >/home/$DEFAULT_USER/.config/code-server/config.yaml
bind-addr: 0.0.0.0:8080
auth: password
password: $PASSWORD
cert: false
EOF
chown -R $DEFAULT_USER:$DEFAULT_USER /home/$DEFAULT_USER/.config
systemctl enable --now code-server@$DEFAULT_USER
#systemctl restart code-server@$DEFAULT_USER

# enable let's encrypt
IPADDR=$(hostname -i | awk '{ print  $1 }')
if [ ${SSL} -eq 1 ]; then
  NAME="@"
  apt-get -y install certbot jq
  if [ -n "${DOMAIN}" ]; then
    if [ $(echo ${DOMAIN} | grep -c "\.${DOMAIN_ZONE}$") -eq 1 ]; then
      NAME=$(echo ${DOMAIN} | sed "s/\.${DOMAIN_ZONE}$//")
    elif [ "${DOMAIN}" != "${DOMAIN_ZONE}" ]; then
      echo "The domain is not included in your Zone"
      _motd fail
    fi
  else
    DOMAIN=${DOMAIN_ZONE}
  fi
  # check NS record
  if [ $(dig ${DOMAIN_ZONE} ns +short | egrep -c '^ns[0-9]+.gslb[0-9]+.sakura.ne.jp.$') -ne 2 ]; then
    echo "Sakura Cloud DNS is not set to NS record in your zone."
    _motd fail
  fi
  # check A record
  if [ $(dig ${DOMAIN} A +short | grep -vc "^$") -ne 0 ]; then
    echo "A record of ${DOMAIN} is already registered."
    _motd fail
  fi
  CZONE=$(jq -r ".Zone.Name" /root/.sacloud-api/server.json)
  BASE=https://secure.sakura.ad.jp/cloud/zone/${CZONE}/api/cloud/1.1
  API=${BASE}/commonserviceitem/
  RESJS=resource.json
  ADDJS=add.json
  UPDATEJS=update.json
  RESTXT=response.txt
  curl -s -v --user "${KEY}" "${API}" 2>"${RESTXT}" | jq -r ".CommonServiceItems[] | select(.Status.Zone == \"${DOMAIN_ZONE}\")" >${RESJS}
  if [ $(grep -c "Status: 200 OK" ${RESTXT}) -ne 1 ]; then
    echo "API connect error"
    _motd fail
  fi
  rm -f ${RESTXT}
  # get resource ID
  RESID=$(jq -r .ID ${RESJS})
  API=${API}${RESID}
  RECODES=$(jq -r ".Settings.DNS.ResourceRecordSets" ${RESJS})
  if [ $(echo "${RECODES}" | egrep -c "^(\[\]|null)$") -ne 1 ]; then
    if [ -n "${RECODES}" ]; then
      if [ "${DOMAIN}" = "${DOMAIN_ZONE}" ]; then
        echo "レコードを登録していないドメインを指定してください"
        _motd fail
      fi
    else
      echo "We could not get domain resource."
      _motd fail
    fi
  fi
  cat <<EOF >${ADDJS}
[
    { "Name": "${NAME}", "Type": "A", "RData": "${IPADDR}" }
]
EOF
  cat <<EOF >${UPDATEJS}
{
  "CommonServiceItem": {
    "Settings": {
      "DNS":  {
        "ResourceRecordSets": $(echo "${RECODES}" | jq -r ".+$(cat ${ADDJS})")
      }
    }
  }
}
EOF
  curl -s -v --user "${KEY}" -X PUT -d "$(cat ${UPDATEJS} | jq -c .)" "${API}" 2>${RESTXT} | jq "."
  if [ $(grep -c "Status: 200 OK" ${RESTXT}) -ne 1 ]; then
    echo "API connect error"
    _motd fail
  fi
  rm -f ${RESTXT}

  DNS_APPLY=0

  for ((i = 0; i < 10; i++)); do
    echo "waiting command   loop: $i"
    sleep 10
    if [ $(dig ${DOMAIN} A +short | grep -vc "^$") -ne 0 ]; then
      DNS_APPLY=1
      break
    fi
  done

  if [ ${DNS_APPLY} -ne 0 ]; then
    certbot --non-interactive --redirect --agree-tos --nginx -d $DOMAIN -m $EMAIL
  else
    echo "error: DNS apply"
    _motd fail
  fi
fi

_motd end
