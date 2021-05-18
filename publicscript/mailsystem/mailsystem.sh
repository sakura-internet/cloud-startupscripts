#!/bin/bash
#
# @sacloud-name "mailsystem"
# @sacloud-once
# @sacloud-tag @require-core>=1 @require-memory-gib>=2
# @sacloud-desc-begin
# さくらのクラウド上で メールサーバを 自動的にセットアップするスクリプトです
# このスクリプトは、AlmaLinux 8.X でのみ動作します
# セットアップには20分程度時間がかかります
#
# 事前作業として以下の2つが必要となります
# ・さくらのクラウドDNSのゾーンにメールサーバで使用するドメインを登録していること
# ・さくらのクラウドAPIのアクセストークンを取得していること
# 注意
# ・ホスト名にはドメインを含めないこと(例: mail)
# ・使用するDNSのゾーンはリソースレコードが未登録であること
# ・ローカルパートが下記のメールアドレスはシステムで利用するため、入力しないこと
#   [ admin root postmaster abuse nobody dmarc-report archive ]
# ・セットアップ後、サーバを再起動します
# ・cockpit を有効にする場合、管理ユーザのパスワードを必ず設定してください
# ・usacloud と certbot の動作の為、ACCESS_TOKEN と ACCESS_TOKEN_SECRET をサーバに保存します
# @sacloud-desc-end
#
# @sacloud-require-archive distro-alma distro-ver-8.*
# @sacloud-textarea required heredoc ADDR "作成するメールアドレスのリスト" ex="foo@example.com"
# @sacloud-apikey required permission=create AK "APIキー"
# @sacloud-text required MAILADDR "セットアップ完了メールを送信する宛先" ex="foobar@example.com"
# @sacloud-checkbox default= archive "メールアーカイブを有効にする"
# @sacloud-checkbox default= cockpit "cockpitを有効にする"

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

LANG=C export LANG

set -ex

#-- スタートアップスクリプト開始
_motd start
trap '_motd fail' ERR

#-- CentOS Stream 8 は 通信が可能になるまで少し時間がかかる
if [ $(grep -c "CentOS Stream release 8" /etc/redhat-release) -eq 1 ]
then
  sleep 30
fi

#-- tool のインストールと更新
dnf install -y bind-utils telnet jq expect bash-completion sysstat mailx git tar chrony

#-- dnf update
dnf update -y

#-- enable PowerTools 
dnf config-manager --set-enabled PowerTools || dnf config-manager --set-enabled powertools

set +x

#-- usacloud のインストール
dnf clean all
(curl -fsSL https://releases.usacloud.jp/usacloud/repos/install.sh | bash || true)
zone=$(dmidecode -t system | awk '/Family/{print $NF}')

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

#-- セットアップスクリプトをダウンロード
git clone https://github.com/sakura-internet/cloud-startupscripts.git
cd cloud-startupscripts/publicscript/mailsystem
source config.source

#-- 特殊タグの展開
mkdir -p ${WORKDIR}
addr_list=${WORKDIR}/address.list
cat > ${addr_list} @@@ADDR@@@
mail_addr="@@@MAILADDR@@@"
pass_list=${WORKDIR}/password.list

#-- ドメイン、アドレス情報の取得
domain_list="$(awk -F@ '{print $2}' ${addr_list} | sort | uniq | tr '\n' ' ' | sed 's/ $//')"
first_address=$(egrep -v "^$|^#" ${addr_list} | grep '@' | head -1 )
first_domain=$(echo ${first_address} | awk -F@ '{print $2}' )

domain_level=$(for x in ${domain_list}; do echo ${x} | awk '{cnt += (split($0, a, ".") - 1)}END{print cnt}'; done)
min_domain_level=$(($(echo "${domain_level}" | sort -n | head -1) + 1))
max_domain_level=$(($(echo "${domain_level}" | sort -nr | head -1) + 1))

#-- ipaddress の取得
source /etc/sysconfig/network-scripts/ifcfg-eth0

#-- セットアップ設定ファイルの修正
rpassword=$(mkpasswd -l 12 -d 3 -c 3 -C 3 -s 0)
sed -i -e "s/^DOMAIN_LIST=.*/DOMAIN_LIST=\"${domain_list}\"/" \
  -e "s/^FIRST_DOMAIN=.*/FIRST_DOMAIN=\"${first_domain}\"/" \
  -e "s/^FIRST_ADDRESS=.*/FIRST_ADDRESS=\"${first_address}\"/" \
  -e "s/^ROOT_PASSWORD=.*/ROOT_PASSWORD=${rpassword}/" \
  -e "s/^IPADDR=.*/IPADDR=${IPADDR}/" \
  -e "s/^MIN_DOMAIN_LEVEL=.*/MIN_DOMAIN_LEVEL=${min_domain_level}/" \
  -e "s/^MAX_DOMAIN_LEVEL=.*/MAX_DOMAIN_LEVEL=${max_domain_level}/" config.source

#-- cockpit 確認
COCKPIT=@@@cockpit@@@
echo "COCKPIT=${COCKPIT}" >> config.source

if [ ! -z ${COCKPIT} ]
then
cat <<_EOL_>>cockpit.txt
-- Cockpit --
LOGIN URL : https://${first_domain}/cockpit

_EOL_
else
  touch cockpit.txt
fi

#-- セットアップ実行
for x in ./setup_scripts/_[0-9]*.sh
do
  ${x} 2>&1
done

#-- メールアーカイブの設定
ARCHIVE=@@@archive@@@
if [ ! -z ${ARCHIVE} ]
then
  for domain in ${domain_list}
  do
    #-- ldap にメールアドレスを登録
    mail_password=$(./tools/389ds_create_mailaddress.sh archive@${domain})
    echo "archive@${domain}: ${mail_password}" >> ${pass_list}

    # 送信アーカイブ設定
    echo "/^(.*)@${domain}\$/    archive+\$1-Sent@${domain}" >> /etc/postfix/sender_bcc_maps
    postconf -c /etc/postfix -e sender_bcc_maps=regexp:/etc/postfix/sender_bcc_maps

    # 受信アーカイブ設定
    if [ ! -f /etc/postfix-inbound/recipient_bcc_maps ]
    then
cat <<_EOL_>/etc/postfix-inbound/recipient_bcc_maps
if !/^archive\+/
/^(.*)@${domain}\$/  archive+\$1-Recv@${domain}
endif
_EOL_
    else
      sed -i "2i /^(.*)@${domain}\$/  archive+\$1-Recv@${domain}" /etc/postfix-inbound/recipient_bcc_maps
    fi
    postconf -c /etc/postfix-inbound -e recipient_bcc_maps=regexp:/etc/postfix-inbound/recipient_bcc_maps

    # 1年経過したアーカイブメールを削除
    echo "0 $((${RANDOM}%6+1)) * * * root doveadm expunge -u archive@${domain} mailbox \*-Sent before 365d" >> ${CRONFILE}
    echo "0 $((${RANDOM}%6+1)) * * * root doveadm expunge -u archive@${domain} mailbox \*-Recv before 365d" >> ${CRONFILE}
  done
fi

#-- ldap にメールアドレスを登録
ignore_list="admin|root|postmaster|abuse|nobody|dmarc-report|archive"
for x in $(egrep -v "^$|^#" ${addr_list} | egrep -v "^(${ignore_list})@"| grep @ | sort | uniq)
do
  mail_password=$(./tools/389ds_create_mailaddress.sh ${x})
  echo "${x}: ${mail_password}" >> ${pass_list}
done

# セットアップ完了のメールを送信
if [ $(echo ${mail_addr} | egrep -c "@") -eq 1 ]
then
	echo -e "Subject: Setup Mail Server - ${first_domain}
From: admin@${first_domain}
To: ${mail_addr}

-- Mail Server Domain --
smtp server : ${first_domain}
pop  server : ${first_domain}
imap server : ${first_domain}

-- Rspamd Webui --
LOGIN URL : https://${first_domain}/rspamd
PASSWORD  : ${rpassword}

-- phpLDAPadmin --
LOGIN URL : https://${first_domain}/phpldapadmin
LOGIN_DN  : ${ROOT_DN}
PASSWORD  : ${rpassword}

-- Roundcube Webmail --
LOGIN URL : https://${first_domain}/roundcube

$(cat cockpit.txt)

$(./tools/check_mailsystem.sh 2>&1)

-- Mail Address and Password --
$(cat ${pass_list})

" | sendmail -f admin@${first_domain} ${mail_addr}
fi

#-- スタートアップスクリプト終了
_motd end

#-- reboot
shutdown -r 1
