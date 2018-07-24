#!/bin/bash

# @sacloud-name "WordPress for KUSANAGI8"
# @sacloud-once
#
# @sacloud-require-archive pkg-kusanagi
#
# @sacloud-desc-begin
#   KUSANAGI8 環境に WordPress をセットアップするスクリプトです。
#   このスクリプトを使うと kusanagi ユーザで ssh ログイン可能になります。
#   サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
#   https://サーバのIPアドレス/
#   ※ セットアップには5?10分程度時間がかかります。
#   セットアップが正常に完了すると、 管理ユーザーのメールアドレス宛に完了メールが送付されます（お使いの環境によってはスパムフィルタにより受信されない場合があります）
#   メール送信後、サーバを再起動をしますのメールを受信したら1分ほど待ってアクセスください。
#   （このスクリプトは、KUSANAGI8.xでのみ動作します）
#
#   セットアップ後は、kusanagiのSSL(Let's Encrypt)設定や、WordPress のURL設定をIPアドレスからドメイン名に変更する設定の実施をおすすめします。
#   詳細は詳細は以下のページを詳細は以下のページをご覧ください
#    http://cloud-news.sakura.ad.jp/wordpress-for-kusanagi8/
# @sacloud-desc-end
#
# 管理ユーザーの入力フォームの設定
# @sacloud-password required shellarg maxlen=60 minlen=6 KUSANAGI_PASSWD  "ユーザー kusanagi のパスワード" ex="6?60文字"
# @sacloud-password required shellarg maxlen=60 minlen=6 DBROOT_PASSWD    "MariaDB root ユーザーのパスワード" ex="6?60文字"
# @sacloud-text     required shellarg maxlen=60 WP_ADMIN_USER    "WordPress 管理者ユーザ名 (半角英数字、下線、ハイフン、ピリオド、アットマーク (@) のみが使用可能)" ex="1?60文字"
# @sacloud-password required shellarg maxlen=60 minlen=6 WP_ADMIN_PASSWD  "WordPress 管理者パスワード" ex="6?60文字"
# @sacloud-text     required shellarg maxlen=256 WP_TITLE        "WordPress サイトのタイトル (256文字以下)"
# @sacloud-text     required  maxlen=128 WP_ADMIN_MAIL   "WordPress 管理者メールアドレス (インストール完了時にメールが送信されます)" ex="user@example.com"

echo "## set default variables";
TERM=xterm

IPADDRESS0=`ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1`
WPDB_USERNAME="wp_`mkpasswd -l 10 -C 0 -s 0`"
WPDB_PASSWORD=`mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2`

echo "## yum update";
yum --enablerepo=remi,remi-php56 update -y || exit 1
sleep 10

#---------START OF kusanagi---------#
echo "## Kusanagi init";
kusanagi init --tz Asia/Tokyo --lang ja --keyboard ja \
  --passwd @@@KUSANAGI_PASSWD@@@ --no-phrase \
  --dbrootpass @@@DBROOT_PASSWD@@@ \
  --nginx --hhvm --ruby24 \
  --dbsystem mariadb || exit 1

echo "## Kusanagi provision";
kusanagi provision \
  --WordPress  --wplang ja \
  --fqdn $IPADDRESS0 \
  --no-email  \
  --dbname $WPDB_USERNAME --dbuser $WPDB_USERNAME --dbpass $WPDB_PASSWORD \
  default_profile  || exit 1

#---------END OF kusanagi---------#

#---------START OF WordPrss---------#

# バックエンドで sudo が動くように設定変更
sed 's/^Defaults    requiretty/#Defaults    requiretty/' -i.bk  /etc/sudoers  || exit 1

# ここからWordPress の設定ファイル作成
echo "## Kusanagi wordpress config";
sudo -u kusanagi -i /usr/local/bin/wp core config \
  --dbname=$WPDB_USERNAME \
  --dbuser=$WPDB_USERNAME \
  --dbpass=$WPDB_PASSWORD \
  --dbhost=localhost --dbcharset=utf8mb4 --extra-php \
  --path=/home/kusanagi/default_profile/DocumentRoot/ \
  < /usr/lib/kusanagi/resource/wp-config-sample/ja/wp-config-extra.php  || exit 1

echo "## Kusanagi wordpress core install";
sudo -u kusanagi  -i /usr/local/bin/wp core install \
  --url=$IPADDRESS0 \
  --title=@@@WP_TITLE@@@ \
  --admin_user=@@@WP_ADMIN_USER@@@  \
  --admin_password=@@@WP_ADMIN_PASSWD@@@ \
  --admin_email="@@@WP_ADMIN_MAIL@@@" \
  --path=/home/kusanagi/default_profile/DocumentRoot/  || exit 1

# sudo の変更を元に戻す
/bin/cp /etc/sudoers.bk /etc/sudoers  || exit 1

#---------END OF WordPrss---------#

# いつ完了しているか分からないため、WP管理者メールアドレスに完了メールを送信

# 必要な情報を集める
SYSTEMINFO=`dmidecode -t system`

# フォームで設定した管理者のアドレスへメールを送信
echo "## send email.";
/usr/sbin/sendmail -t -i -o -f @@@WP_ADMIN_MAIL@@@ << EOF From: @@@WP_ADMIN_MAIL@@@
Subject: finished Wordpress install on $IPADDRESS0
To: @@@WP_ADMIN_MAIL@@@

Finish WordPress install on $IPADDRESS0

Please access to https://$IPADDRESS0 after 1 min.

Autogenerate DBname, DBUsername, DBpassword etc...
You can find Wordpress DB Infomation in /home/kusanagi/default_profile/DocumentRoot/wp-config.php

System Info:
$SYSTEMINFO
EOF

echo "## finished!";
echo "please access to https://$IPADDRESS0/";

echo "## reboot after 10 seconds.";
sh -c 'sleep 10; reboot' &

exit 0