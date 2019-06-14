#!/bin/bash
#
# @sacloud-name "Let's Encrypt"
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトは usacloud, certbot-auto をインストールし、Let's Encryptで "指定ドメイン" と "*.指定ドメイン" のTLS証明書を取得します
# CAA レコードを登録する場合は、 issue と issuewild タグを登録します。
# (CentOS7.X でのみ動作します)
#
# 事前作業として以下の2つが必要となります
# ・さくらのクラウドDNSにゾーン登録を完了していること
# ・さくらのクラウドAPIのアクセストークンを取得していること
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-7
# @sacloud-text required DOMAIN "さくらのクラウドDNSで管理しているDNSゾーン" ex="example.com"
# @sacloud-text required MAILADDR "Let's Encryptから連絡を受信するメールアドレス" ex="sakura@example.com"
# @sacloud-checkbox default= CAA "CAAレコードを登録する"
# @sacloud-apikey required permission=create AK "APIキー"

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

set -ex

#-- スタートアップスクリプト開始
_motd start
trap '_motd fail' ERR

#-- usacloud のインストール
curl -fsSL http://releases.usacloud.jp/usacloud/repos/setup-yum.sh | sh
zone=$(dmidecode -t system | awk '/Family/{print $NF}')

set +x

#-- usacloud の設定
usacloud config --token ${SACLOUD_APIKEY_ACCESS_TOKEN}
usacloud config --secret ${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}
usacloud config --zone ${zone}

#-- certbot で使用する token と secret の設定
cat <<_EOL_> ~/.sakura
dns_sakuracloud_api_token = "${SACLOUD_APIKEY_ACCESS_TOKEN}"
dns_sakuracloud_api_secret = "${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}"
_EOL_
chmod 600 ~/.sakura

set -x

#-- 変数のセット
domain="@@@DOMAIN@@@"
mail_addr="@@@MAILADDR@@@"
caa_flag=@@@CAA@@@
cat > domain.list @@@ADDR@@@

if [ -z ${caa_flag} ]; then
	caa_flag="0"
fi

#-- certbot のインストール
yum install -y certbot certbot-dns-sakuracloud expect

#-- 証明書のインストール
expect -c "
set timeout 180
spawn certbot certonly --dns-sakuracloud --dns-sakuracloud-credentials /root/.sakura --dns-sakuracloud-propagation-seconds 90 -d *.${domain} -d ${domain} -m ${mail_addr} --manual-public-ip-logging-ok --agree-tos
expect \"(Y)es/(N)o:\"
send -- \"Y\n\"
expect \"Congratulations\"
"

#-- 証明書が取得できたか確認
ls -l /etc/letsencrypt/live/${domain}/fullchain.pem

#-- cron に証明書の更新処理を設定
echo "$((${RANDOM}%60)) $((${RANDOM}%24)) * * $((${RANDOM}%7)) root certbot renew " >> /etc/cron.d/update-sacloud-certbot

#-- CAA レコードの登録
if [ ${caa_flag} -ne 0 ]
then
	usacloud dns record-add -y --name @ --type CAA --value '0 issue "letsencrypt.org"' ${domain}
	usacloud dns record-add -y --name @ --type CAA --value '0 issuewild "letsencrypt.org"' ${domain}
fi

_motd end

exit 0
