#!/bin/bash

# @sacloud-name "Drupal for Ubuntu"
# @sacloud-once
#
# @sacloud-require-archive distro-ubuntu distro-ver-18.04.*
#
# @sacloud-desc-begin
#   Drupalをインストールします。
#   サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
#   http://サーバのIPアドレス/
#   ※ セットアップには5分程度時間がかかります。
#   （このスクリプトは、Ubuntu 18.04 でのみ動作します）
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

source /etc/lsb-release

DRUPAL_VERSION=@@@drupal_version@@@

# MySQL サーバーインストールウィザードの設定値をセット
mysql_password=root
mysql_package="mysql-server-5.7"

echo "$mysql_package mysql-server/root_password password $mysql_password" | debconf-set-selections
echo "$mysql_package mysql-server/root_password_again password $mysql_password" | debconf-set-selections

# 必要なミドルウェアを全てインストール
apt-get update || exit 1
required_packages="apache2 libapache2-mod-php mysql-server php php-mbstring php-apcu php-mysql php-gd php-xml composer zip unzip"
apt-get -y install $required_packages

# Apache の rewrite モジュールを有効化
a2enmod rewrite

# Drupal で .htaccess を使用するため /var/www/html ディレクトリに対してオーバーライドを全て許可する
patch -l /etc/apache2/sites-available/000-default.conf << EOS
13a14,16
>    <Directory /var/www/html>
>        AllowOverride All
>    </Directory>
>
EOS

# PHP の各種設定
patch /etc/php/7.0/apache2/php.ini << EOS
656c656
< post_max_size = 8M
---
> post_max_size = 16M
798c798
< upload_max_filesize = 2M
---
> upload_max_filesize = 16M
912c912
< ;date.timezone =
---
> date.timezone = Asia/Tokyo
EOS

service apache2 restart

# 8.xの Drush をダウンロードする
mkdir /opt/composer && cd $_
COMPOSER_HOME="/opt/composer" composer config -g repositories.packagist composer https://packagist.org
COMPOSER_HOME="/opt/composer" composer require "drush/drush":"~8"
drush="$(pwd)/vendor/bin/drush"

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
  --db-url=mysql://root:root@localhost/drupal\
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
chown -R www-data: /var/www/html || exit 1

# Drupal のクロンタスクを作成し一時間に一度の頻度で回す
cat << EOS > /etc/cron.hourly/drupal
#!/bin/bash
$drush -r /var/www/html cron
EOS
chmod 755 /etc/cron.hourly/drupal || exit 1

# レポート画面で利用可能なアップデートに問題があると警告されるため、アップデート
# 処理を行う。
# - 即時アップデート確認を行うとステータス画面で正常と認識されないため、sleep
#   コマンドで1分後に実行する。
# - `--update-backend=drupal` を指定しないと、レポート画面に正しく反映されない。
sleep 1m
$drush -y up --update-backend=drupal || exit 1
