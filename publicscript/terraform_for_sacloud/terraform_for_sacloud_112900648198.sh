#!/bin/bash

# @sacloud-once
# @sacloud-desc-begin
#  CentOS7.xに Terraform for さくらのクラウド をインストールします
#  インストール完了後にターミナルでサーバにログインし、terraformコマンドをご利用ください
#  詳細はクラウドニュースを参照ください：https://cloud-news.sakura.ad.jp/startup-script/terraform-for-sakuracloud/
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-select-begin required default=tk1v default_zone "Terraform for さくらのクラウドで操作するデフォルトゾーン"
#   is1a "石狩第1ゾーン"
#   is1b "石狩第2ゾーン"
#   tk1a "東京第1ゾーン"
#   tk1v "Sandbox"
# @sacloud-select-end
# @sacloud-apikey required permission=create SACLOUD_APIKEY "APIキー"

DEFAULT_ZONE=@@@default_zone@@@

yum install -y openssl

mkdir -p ~/terraform
cd ~/terraform

# Terraformの最新バージョン
version=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases | grep tag_name | grep -v "rc" | head -1 | cut -d '"' -f 4 | sed -e s/v//)
if [ -z "$version" ]; then
  echo 'cannot get terraform version'
  exit 1
fi

# checksum
checksum_file="terraform_${version}_SHA256SUMS"
curl -sL https://releases.hashicorp.com/terraform/${version}/terraform_${version}_SHA256SUMS > $checksum_file

# Terraform
terraform_file="terraform_${version}_linux_amd64.zip"
curl -sL https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip > $terraform_file

actual_checksum=$(openssl dgst -sha256 ${terraform_file} | awk -F '=' '{ gsub(" ","", $2); print $2 }')
echo "debug actual_checksum   => ${actual_checksum}"
expected_checksum=$(cat ${checksum_file} | grep ${terraform_file} | awk '{ print $1 }')
echo "debug expected_checksum => ${expected_checksum}"

if [ ${actual_checksum} != ${expected_checksum} ]; then
  echo 'does not match checksum'
  exit 1
fi

# Terraform for さくらのクラウド
curl -sL https://terraform.b.sakurastorage.jp/downloads/terraform-provider-sakuracloud_linux-amd64.zip > terraform-provider-sakuracloud_linux-amd64.zip

unzip $terraform_file
unzip terraform-provider-sakuracloud_linux-amd64.zip

cat << __EOL__ >> ~/.bash_profile
export PATH=\$PATH:~/terraform/
export SAKURACLOUD_ACCESS_TOKEN="$SACLOUD_APIKEY_ACCESS_TOKEN"
export SAKURACLOUD_ACCESS_TOKEN_SECRET="$SACLOUD_APIKEY_ACCESS_TOKEN_SECRET"
export SAKURACLOUD_ZONE="$DEFAULT_ZONE"
__EOL__

exit 0