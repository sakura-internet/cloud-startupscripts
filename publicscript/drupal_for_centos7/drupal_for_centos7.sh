#!/bin/bash

# @sacloud-name "Drupal for CentOS 7"
# @sacloud-once
#
# @sacloud-require-archive distro-centos distro-ver-7.*
#
# @sacloud-desc-begin
#   Drupalをインストールします。
#   サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
#   http://サーバのIPアドレス/
#   ※ セットアップには5分程度時間がかかります。
#   （このスクリプトは、CentOS7.Xでのみ動作します）
#   セットアップが正常に完了すると、 管理ユーザーのメールアドレス宛に完了メールが送付されます（お使いの環境によってはスパムフィルタにより受信されない場合があります）
# @sacloud-desc-end
#
# Drupal の管理ユーザーの入力フォームの設定
# @sacloud-select-begin required default=7 drupal_version "Drupal バージョン"
#   7 "Drupal 7.x"
#   8 "Drupal 8.x"
# @sacloud-select-end
# @sacloud-text required shellarg maxlen=128 site_name "Drupal サイト名"
# @sacloud-text required shellarg maxlen=60 ex=Admin user_name "Drupal 管理ユーザーの名前"
# @sacloud-password required shellarg maxlen=60 password "Drupal 管理ユーザーのパスワード"
# @sacloud-text required shellarg maxlen=254 ex=your.name@example.com mail "Drupal 管理ユーザーのメールアドレス"

DRUPAL_VERSION=@@@drupal_version@@@

# 必要なミドルウェアを全てインストール
yum makecache fast || exit 1
# Drupal 7, 8 共通のパッケージをインストール
yum -y install mariadb mariadb-server httpd || exit 1
if [ $DRUPAL_VERSION -eq 7 ]; then
  yum -y install php php-mysql php-gd php-dom php-mbstring || exit 1
  yum -y install --enablerepo=remi php-pecl-apcu php-pecl-zendopcache || exit 1
elif [ $DRUPAL_VERSION -eq 8 ]; then
  yum -y install --enablerepo=remi,remi-php56 gd-last php php-mysql php-gd php-dom php-mbstring php-pecl-apcu php-pecl-zendopcache || exit 1
fi

# Drupal で .htaccess を使用するため /var/www/html ディレクトリに対してオーバーライドを全て許可する
patch /etc/httpd/conf/httpd.conf << EOS
151c151
<     AllowOverride None
---
>     AllowOverride All
EOS

# MySQL の max_allowed_packet の設定を 16MB まで引き上げる
patch /etc/my.cnf << EOS
9a10
> max_allowed_packet=16M
EOS

# PHP のデフォルトのタイムゾーンを東京に設定
# Drupal のデフォルトのタイムゾーンにもなる
patch /etc/php.ini << EOS
396c396
< memory_limit = 128M
---
> memory_limit = 192M
663c663
< post_max_size = 8M
---
> post_max_size = 16M
811c811
< upload_max_filesize = 2M
---
> upload_max_filesize = 16M
889c889
< ;date.timezone =
---
> date.timezone = Asia/Tokyo
EOS

# ファイルアップロード時のプログレスバーを表示できるようにする
if [ $DRUPAL_VERSION -eq 7 ]; then
  file_path=/etc/php.d/apcu.ini
elif [ $DRUPAL_VERSION -eq 8 ]; then
  # Drupal 8 の場合は REMI 版の APCu を使うためパスが違う
  file_path=/etc/php.d/40-apcu.ini
fi
patch $file_path << EOS
67c67
< ;apc.rfc1867=0
---
> apc.rfc1867=1
EOS

# MySQL サーバーを自動起動するようにして起動
systemctl enable mariadb.service || exit 1
systemctl start mariadb.service || exit 1

# 最新版の Drush をダウンロードする
php -r "readfile('http://files.drush.org/drush.phar');" > drush || exit 1

# drush コマンドを実行可能にして /usr/local/bin に移動
chmod +x drush || exit 1
mv drush /usr/local/bin || exit 1
drush=/usr/local/bin/drush

# Drupal をダウンロード
if [ $DRUPAL_VERSION -eq 7 ]; then
  project=drupal-7
elif [ $DRUPAL_VERSION -eq 8 ]; then
  project=drupal-8
fi
$drush -y dl $project --destination=/var/www --drupal-project-rename=html || exit 1

# アップロードされたファイルを保存するためのディレクトリを用意
mkdir /var/www/html/sites/default/files /var/www/html/sites/default/private || exit 1

# Drupal サイトのルートディレクトリに移動して drush コマンドに備える
cd /var/www/html

# Drupal をインストール
$drush -y si\
  --db-url=mysql://root@localhost/drupal\
  --locale=ja\
  --account-name=@@@user_name@@@\
  --account-pass=@@@password@@@\
  --account-mail=@@@mail@@@\
  --site-name=@@@site_name@@@ || exit 1

if [ $DRUPAL_VERSION -eq 7 ]; then
  # Drupal をローカライズするためのモジュールを有効化
  $drush -y en locale || exit 1

  # 日本のロケール設定
  $drush -y vset site_default_country JP || exit 1

  # 日本語をデフォルトの言語として追加
  # drush_language モジュールも使えるが、スタートアップスクリプトでは上手く
  # 動かないので eval を使う
  $drush eval "locale_add_language('ja', 'Japanese', '日本語');" || exit 1
  $drush eval '$langs = language_list(); variable_set("language_default", $langs["ja"])' || exit 1

  # 最新の日本語ファイルを取り込むモジュールをダウンロードしてインストール
  $drush -y dl l10n_update || exit 1
  $drush -y en l10n_update || exit 1

  # 最新の日本語情報を取得してインポート
  $drush l10n-update-refresh || exit 1
  $drush l10n-update || exit 1
elif [ $DRUPAL_VERSION -eq 8 ]; then
  # 日本語翻訳のインポート
  $drush locale-check || exit 1
  $drush locale-update || exit 1

  # 日本語訳がキャッシュにより中途半端な状態になることがあるので、キャッシュをリビルトする
  $drush cr || exit 1
fi

# Drupal のルートディレクトリ (/var/www/html) 以下の所有者を apache に変更
chown -R apache: /var/www/html || exit 1

# Drupal のクロンタスクを作成し一時間に一度の頻度で回す
cat << EOS > /etc/cron.hourly/drupal
#!/bin/bash
/usr/local/bin/drush -r /var/www/html cron
EOS
chmod 755 /etc/cron.hourly/drupal || exit 1

# Apache を自動起動する
systemctl enable httpd.service || exit 1

# Apache を起動する
systemctl start httpd.service || exit 1

# ファイアウォールに対し http プロトコルでのアクセスを許可する
firewall-cmd --add-service=http || exit 1

# レポート画面で利用可能なアップデートに問題があると警告されるため、アップデート
# 処理を行う。
# - 即時アップデート確認を行うとステータス画面で正常と認識されないため、sleep
#   コマンドで1分後に実行する。
# - `--update-backend=drupal` を指定しないと、レポート画面に正しく反映されない。
sleep 1m
$drush -y up --update-backend=drupal || exit 1

# いつ完了しているか分からないため、管理者メールアドレスに完了メールを送信

# 必要な情報を集める
IP=`ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1`
SYSTEMINFO=`dmidecode -t system`

# フォームで設定した管理者のアドレスへメールを送信
/usr/sbin/sendmail -t -i -o -f @@@mail@@@ << EOF From: @@@mail@@@
Subject: finished drupal install on $IP
To: @@@mail@@@

Finished drupal install on $IP

Please access to http://$IP

System Info:
$SYSTEMINFO
EOF