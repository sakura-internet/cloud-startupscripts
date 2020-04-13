#!/bin/bash

# @sacloud-name "Jitsi Meet"
# @sacloud-once
# @sacloud-desc-begin
# Jitsi Meet をインストールするスクリプトです。
# このスクリプトは Ubuntu Server 18.04 系でのみ動作します。
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
# https://github.com/jitsi/jitsi-meet/blob/master/doc/quick-install.md#generate-a-lets-encrypt-certificate-optional-recommended
#
# @sacloud-desc-end
# @sacloud-require-archive distro-ubuntu distro-ver-18.04*
# @sacloud-text required DNS_ZONE "さくらのクラウドDNSで管理しているDNSゾーン" ex="example.com"
# @sacloud-apikey required permission=create API_KEY "APIキー"

set -eux
apt-get update

# スタートアップスクリプト内の特殊変数をシェルの変数に代入。
dns_zone="@@@DNS_ZONE@@@"

# さくらのクラウドを API で操作するため usacloud をインストール。
# https://github.com/sacloud/usacloud/tree/ac47348d5200c5c5ce126f950d807ef45a01775d#macosbrew--linuxapt-or-yum-or-brew--bash-on-windowsubuntu
apt-get install -y curl gnupg2 jq
curl -fsSL https://releases.usacloud.jp/usacloud/repos/install.sh | bash
usacloud config --token "${SACLOUD_APIKEY_ACCESS_TOKEN}"
usacloud config --secret "${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}"
usacloud config --zone "$(jq -r .Zone.Name /root/.sacloud-api/server.json)"
usacloud config --default-output-type "json"

# usacloud でさくらのクラウドのDNSゾーンにリソースレコードを追加。
dns_records_size="$(usacloud dns read ${dns_zone} | jq '.[0].Settings.DNS.ResourceRecordSets | length')"
if [ "${dns_records_size}" != "0" ]; then
  echo "リソースレコードは未登録のままの状態にしておいてください。"
  exit 1
fi

ip_address=$(jq -r .Interfaces[0].IPAddress /root/.sacloud-api/server.json)
usacloud dns record-add -y --name '@' --type 'A' --value "${ip_address}" "${dns_zone}"

# jitsi-meet のインストール。
# via https://github.com/jitsi/jitsi-meet/blob/a85c72d85967dea7fc79aba08db59b8855ca140d/doc/quick-install.md
apt-get install -y apt-transport-https

echo 'deb https://download.jitsi.org stable/' >> /etc/apt/sources.list.d/jitsi-stable.list
wget -qO - https://download.jitsi.org/jitsi-key.gpg.key | apt-key add -

apt-get update

# jitsi-meet インストール時に TUI で手動入力する項目の自動化。
echo "jitsi-videobridge2 jitsi-videobridge/jvb-hostname string ${dns_zone}" | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive

apt-get install -y jitsi-meet
