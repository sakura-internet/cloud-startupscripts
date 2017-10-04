#!/bin/bash
#
# @sacloud-name "MailSystem"
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトはメールサーバをセットアップします
# (このスクリプトは、CentOS7.Xでのみ動作します)
#
# 事前作業として以下の2つが必要となります
# ・さくらのクラウドDNSにメールアドレスのドメインとして使用するゾーンを登録していること
# ・さくらのクラウドAPIのアクセストークンを取得していること
# 注意
# ・使用するDNSゾーンはリソースレコードが未登録であること
# ・ホスト名の入力はドメインを含めないこと(例: mail)
# ・ローカルパートが下記のメールアドレスは自動で作成するため、入力しないこと
#   [admin root postmaster abuse virus-report nobody]
# ・セットアップ後、サーバを再起動します
# @sacloud-desc-end
#
# @sacloud-require-archive distro-centos distro-ver-7
# @sacloud-textarea required heredoc ADDR "作成するメールアドレスのリスト" ex="foo@example.com"
# @sacloud-apikey required permission=create AK "APIキー"
# @sacloud-text required MAILADDR "セットアップ完了メールを送信する宛先" ex="foobar@example.com"

KEY="${SACLOUD_APIKEY_ACCESS_TOKEN}:${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}"
export KEY=${KEY}

set -x
START=$(date)

# install tools
yum remove -y epel-release
yum install -y epel-release
yum install -y expect telnet bind-utils jq mailx git dstat sysstat

# git repository
git clone https://github.com/sakura-internet/cloud-startupscripts.git
source cloud-startupscripts/publicscript/mailsystem/config.source
cd cloud-startupscripts/publicscript/mailsystem

source ./setup_scripts/_startup_function.lib
_motd start

set -e
trap '_motd fail' ERR

# yum update
yum update -y

# 特殊タグの展開
mkdir -p ${WORKDIR}
ADDR_LIST=${WORKDIR}/address.list
cat > ${ADDR_LIST} @@@ADDR@@@
MAILADDR="@@@MAILADDR@@@"
PASS_LIST=${WORKDIR}/password.list

# ドメイン、アドレス情報の取得
DOMAIN_LIST="$(awk -F@ '{print $2}' ${ADDR_LIST} | sort | uniq | tr '\n' ' ' | sed 's/ $//')"
FIRST_ADDRESS=$(egrep -v "^$|^#" ${ADDR_LIST} | grep '@' | head -1 )
FIRST_DOMAIN=$(echo ${FIRST_ADDRESS} | awk -F@ '{print $2}' )

# ipaddress の取得
source /etc/sysconfig/network-scripts/ifcfg-eth0

# セットアップ設定ファイルの修正
PASSWORD=$(mkpasswd -l 12 -d 3 -c 3 -C 3 -s 0)
sed -i "s/^DOMAIN_LIST=.*/DOMAIN_LIST=\"${DOMAIN_LIST}\"/" config.source
sed -i "s/^FIRST_DOMAIN=.*/FIRST_DOMAIN=\"${FIRST_DOMAIN}\"/" config.source
sed -i "s/^FIRST_ADDRESS=.*/FIRST_ADDRESS=\"${FIRST_ADDRESS}\"/" config.source
sed -i "s/^ROOT_PASSWORD=.*/ROOT_PASSWORD=${PASSWORD}/" config.source
sed -i "s/^IPADDR=.*/IPADDR=${IPADDR}/" config.source

# openldap のセットアップ
./setup_scripts/_setup_openldap.sh 2>&1

# admin 用メールアドレスの登録
./setup_scripts/_create_admin_address.sh 2>&1

# メールアドレスの登録
for x in $(egrep -v "^$|^#" ${ADDR_LIST} | grep @ | sort | uniq)
do
	MAIL_PASSWORD=$(./setup_scripts/_create_mailaddress.sh ${x})
	echo "${x}: ${MAIL_PASSWORD}" >> ${PASS_LIST}
done

# opendkim のセットアップ
./setup_scripts/_setup_opendkim.sh 2>&1

# DNS レコードの登録、ホスト名の設定
./setup_scripts/_setup_dns.sh 2>&1

# dovecot, pigeonhole のセットアップ
./setup_scripts/_setup_dovecot.sh 2>&1

# clamav, clamav-milter のセットアップ
./setup_scripts/_setup_clamd.sh 2>&1

# yenma のセットアップ
./setup_scripts/_setup_yenma.sh 2>&1

# postfix のセットアップ
./setup_scripts/_setup_postfix.sh 2>&1

# nginx のセットアップ
./setup_scripts/_setup_nginx.sh 2>&1

# mariadb のセットアップ
./setup_scripts/_setup_mariadb.sh 2>&1

# roundcube のセットアップ
./setup_scripts/_setup_roundcube.sh 2>&1

# phpldapadmin のセットアップ
./setup_scripts/_setup_phpldapadmin.sh 2>&1

# DNS の逆引き登録
./setup_scripts/_setup_dns_ptr.sh 2>&1

# サービスポートのオープン
for x in 25 80 587 443 465 993 995
do
	firewall-cmd --permanent --add-port=${x}/tcp
done
firewall-cmd --reload

# Lets Encrypt から SSL 証明書取得
./setup_scripts/_setup_ssl.sh 2>&1

# rainloop のセットアップ
./setup_scripts/_setup_rainloop.sh 2>&1

# thunderbird の autoconfig 設定
./setup_scripts/_setup_thunderbird.sh 2>&1

END=$(date)

set +x

# セットアップ完了のメールを送信
if [ $(echo ${MAILADDR} | egrep -c "@") -eq 1 ]
then
	echo -e "Subject: Setup Mail Server - ${FIRST_DOMAIN}
From: admin@${FIRST_DOMAIN}
To: ${MAILADDR}

SETUP START : ${START}
SETUP END   : ${END}

-- Mail Server Domain --
smtp server : ${FIRST_DOMAIN}
pop  server : ${FIRST_DOMAIN}
imap server : ${FIRST_DOMAIN}

-- phpLDAPadmin --
LOGIN URL : https://${FIRST_DOMAIN}/phpldapadmin
LOGIN_DN  : ${ROOT_DN}
PASSWORD  : ${PASSWORD}

-- Roundcube Webmail --
LOGIN URL : https://${FIRST_DOMAIN}/roundcube

-- RainLoop Webmail --
ADMIN URL      : https://${FIRST_DOMAIN}/rainloop/?admin
ADMIN USER     : admin
ADMIN PASSWORD : 12345
LOGIN URL      : https://${FIRST_DOMAIN}/rainloop

$(./setup_scripts/_setup_check.sh 2>&1)

-- create Mail Address and Password List --
$(cat ${PASS_LIST})

" | sendmail -f admin@${FIRST_DOMAIN} ${MAILADDR}
fi

_motd end

# reboot
shutdown -r 1
