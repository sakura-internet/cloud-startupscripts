#!/bin/bash

# @sacloud-name "Jitsi Meet"
# @sacloud-once
# @sacloud-desc-begin
# Jitsi Meet をインストールするスクリプトです。
# このスクリプトは Ubuntu Server 18.04, 20.04 系で動作します。
#
# 事前に下記の作業が必要です。
#
# * Jitsi Meet 用のドメインのご用意。
#   * お客様の所有ドメインをお持ち込みいただくか、弊社ドメイン取得サービス https://domain.sakura.ad.jp/ をご利用ください。
# * さくらのクラウドDNSにゾーンの追加。
#   * 追加方法は https://manual.sakura.ad.jp/cloud/appliance/dns/index.html をご覧ください。
#   * さくらのクラウドDNSにゾーンの追加後、リソースレコードは未登録のままの状態にしておいてください。
# * さくらのクラウドAPIキーの作成。
#   * 作成方法は https://manual.sakura.ad.jp/cloud/api/apikey.html をご覧ください。
#
# セットアップの目安時間は約10分です。
# セットアップ完了後「https://さくらのクラウドDNSのゾーン名」にアクセスしてください。
# また、セットアップ完了後、以下の Jitsi Meet のドキュメントを参考に Let's Encrypt の設定なども行うことができます。
# https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-quickstart
#
# @sacloud-desc-end
# @sacloud-require-archive distro-ubuntu distro-ver-18.04
# @sacloud-require-archive distro-ubuntu distro-ver-20.04
# @sacloud-text required DNS_ZONE "ホスト名（ドメインはDNSアプライアンスで管理されている必要があります）" ex="example.com"
# @sacloud-apikey required permission=create API_KEY "APIキー"

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

_motd start

set -eux
apt-get update

# スタートアップスクリプト内の特殊変数をシェルの変数に代入。
dns_zone="@@@DNS_ZONE@@@"

# さくらのクラウドを API で操作するため usacloud をインストール。
# https://docs.usacloud.jp/usacloud/installation/start_guide/
apt-get install -y curl gnupg2 jq
curl -fsSL https://github.com/sacloud/usacloud/releases/latest/download/install.sh | bash
usacloud config --token "${SACLOUD_APIKEY_ACCESS_TOKEN}"
usacloud config --secret "${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}"
usacloud config --zone "$(jq -r .Zone.Name /root/.sacloud-api/server.json)"
usacloud config --default-output-type "json"

# usacloud でさくらのクラウドのDNSゾーンにリソースレコードを追加。
dns_records_size="$(usacloud dns read ${dns_zone} | jq '.[0].Records | length')"
if [ "${dns_records_size}" != "0" ]; then
  echo "リソースレコードは未登録のままの状態にしておいてください。"
  exit 1
fi

ip_address=$(jq -r .Interfaces[0].IPAddress /root/.sacloud-api/server.json)
usacloud dns update ${dns_zone} -y --parameters '{"Records": [{ "Name": "@", "Type": "A", "RData": "'${ip_address}'" }]}'

# jitsi-meet のインストール。
# via https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-quickstart
apt-get install -y nginx-full apt-transport-https openjdk-8-jdk software-properties-common

apt-add-repository universe

# Ubuntu 18.04 用に Prosody パッケージリポジトリの追加
# via https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-quickstart#for-ubuntu-1804-add-prosody-package-repository
if [[ $(lsb_release -rs) == "18.04" ]]; then
  echo deb http://packages.prosody.im/debian $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list
  wget https://prosody.im/files/prosody-debian-packages.key -O- | sudo apt-key add -
fi

curl https://download.jitsi.org/jitsi-key.gpg.key | sudo sh -c 'gpg --dearmor > /usr/share/keyrings/jitsi-keyring.gpg'
echo 'deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/' | sudo tee /etc/apt/sources.list.d/jitsi-stable.list > /dev/null

apt-get update

# jitsi-meet インストール時に TUI で手動入力する項目の自動化。
echo "jitsi-videobridge2 jitsi-videobridge/jvb-hostname string ${dns_zone}" | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive

# ufw のセットアップ
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 10000/udp
ufw allow 22/tcp
ufw allow 3478/udp
ufw allow 5349/tcp
ufw enable

apt-get install -y jitsi-meet

_motd end
