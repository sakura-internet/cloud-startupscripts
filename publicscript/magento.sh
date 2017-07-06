#!/bin/bash

# @sacloud-once

# @sacloud-desc Ubuntu16.04.* LTSに、EC サイト構築プラットフォーム Magento2.x をインストールします。
# @sacloud-desc ※ホスト名は名前解決が出来る名前の設定を推奨します。
# @sacloud-desc ※推奨スペック：CPU:４Core以上 Memory:8GB以上　（低スペックの場合インストールが正常に終了しない場合があります）
# @sacloud-desc ※サーバ作成前に Magento マーケットプレイスにログインし、「Marketplaceのpublic key」と「Marketplaceのprivate key」の取得が必要です。
# @sacloud-desc ログインは https://account.magento.com/applications/customer/login から行えます。
# @sacloud-desc public key および private key は、 https://marketplace.magento.com/customer/accessKeys/list/ から既存のものを参照するか、新規に作成ください。
# @sacloud-desc ※サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
# @sacloud-desc http://サーバのIPアドレス/
# @sacloud-desc ※アカウント・パスワードは管理者メールアドレスにメールされます。（環境によりスパムフィルター等でフィルタされる場合があります。）
# @sacloud-desc サーバ上の /home/ubuntu/info.txt にも保存されているため確認後削除してください。
# @sacloud-desc （このスクリプトは、Ubuntu16.04.* LTSでのみ動作します）
# @sacloud-require-archive distro-ubuntu distro-ver-16.04.*
# @sacloud-text required shellarg maxlen=100 admin_email "Magento管理者アカウントのメールアドレス"
# @sacloud-text required shellarg maxlen=100 marketplace_public "Magento Marketplaceのpublic key"
# @sacloud-text required shellarg maxlen=100 marketplace_private "Magento Marketplaceのprivate key"
# @sacloud-checkbox default=on deploy_sample_data "Magentoのサンプルデータをインストールする"

ADMIN_EMAIL=@@@admin_email@@@
MM_PUBLIC=@@@marketplace_public@@@
MM_PRIVATE=@@@marketplace_private@@@
MAGENTO_INSTALL_SAMPLE=@@@deploy_sample_data@@@
POSTFIX_HOST_NAME=`uname -n`

export DEBIAN_FRONTEND=noninteractive

echo "## Set up ufw"
ufw allow 22 || exit 1
ufw allow 80 || exit 1
ufw allow 443 || exit 1
ufw enable || exit 1

echo "## Update apt information"
apt-get update || exit 1
apt-get install pwgen || exit 1

ADMIN_USER="mage_`pwgen -Bvscn 8 1`"
ADMIN_PASSWORD="`pwgen -Bvscn 16 1`"
ADMIN_PATH="admin_`pwgen -Bvscn 8 1`"
NEWMYSQLPASSWORD="`pwgen -Bvscn 16 1`"
MAGENTO_DB_USER="mage_`pwgen -Bvscn 8 1`"
MAGENTO_DB_PASSWORD="`pwgen -Bvscn 16 1`"
MAGENTO_DB_SCHEMA="magento_`pwgen -Bvscn 8 1`"

echo "## Retrive IP Address"
IP_ADDR=`ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1` || exit 1

# アカウント情報を出力
echo "ログインURLにアクセスして管理者IDとパスワードでアクセスしてください。初回ログイン後にパスワード変更をお勧めします。" >> /home/ubuntu/info.txt || exit 1
echo "ログインURL:http://$IP_ADDR/index.php/$ADMIN_PATH" >> /home/ubuntu/info.txt || exit 1
echo "管理者ID: $ADMIN_USER" >> /home/ubuntu/info.txt || exit 1
echo "管理者パスワード: $ADMIN_PASSWORD" >> /home/ubuntu/info.txt || exit 1
/bin/cp  /home/ubuntu/info.txt  /home/ubuntu/info2.txt || exit 1
chown ubuntu. /home/ubuntu/info2.txt || exit 1
chmod 600 /home/ubuntu/info2.txt || exit 1
echo "その他のパスワードは /home/ubuntu/info.txt を参照してください" >> /home/ubuntu/info2.txt || exit 1

echo "MySQLのrootパスワード: $NEWMYSQLPASSWORD" >> /home/ubuntu/info.txt || exit 1
echo "Magentoをインストールしたデータベーススキーマ: $MAGENTO_DB_SCHEMA" >> /home/ubuntu/info.txt || exit 1
echo "MySQLのMAGENTO　ユーザ: $MAGENTO_DB_USER" >> /home/ubuntu/info.txt || exit 1
echo "MySQLのMAGENTO　パスワード: $MAGENTO_DB_PASSWORD" >> /home/ubuntu/info.txt || exit 1
echo "本ファイルは確認後、削除してください" >> /home/ubuntu/info.txt || exit 1
chown ubuntu. /home/ubuntu/info.txt || exit 1
chmod 600 /home/ubuntu/info.txt || exit 1

echo "## Install MySQL"
debconf-set-selections <<< "mysql-server mysql-server/root_password password $NEWMYSQLPASSWORD" || exit 1
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $NEWMYSQLPASSWORD" || exit 1
apt-get install -y mysql-server-5.7 mysql-client-5.7 || exit 1
apt-get install -y software-properties-common || exit 1
apt-get install -y python-software-properties || exit 1
add-apt-repository ppa:ondrej/php || exit 1
apt-get update || exit 1
cat << EOT > /etc/mysql/my.cnf || exit 1
[client]
port  = 3306
socket  = /var/run/mysqld/mysqld.sock
default-character-set=utf8mb4
[mysqld_safe]
socket  = /var/run/mysqld/mysqld.sock
nice  = 0

[mysqld]
user  = mysql
pid-file = /var/run/mysqld/mysqld.pid
socket  = /var/run/mysqld/mysqld.sock
port  = 3306
basedir  = /usr
datadir  = /var/lib/mysql
tmpdir  = /tmp
character-set-server = utf8mb4
bind-address  = 127.0.0.1
EOT

echo "## Configure MySQL Remote Access"
MYSQLAUTH="--user=root --password=$NEWMYSQLPASSWORD" || exit 1
mysql $MYSQLAUTH -e "CREATE DATABASE $MAGENTO_DB_SCHEMA;" || exit 1
mysql $MYSQLAUTH -e "GRANT ALL ON $MAGENTO_DB_SCHEMA.* TO '$MAGENTO_DB_USER'@'localhost' IDENTIFIED BY '$MAGENTO_DB_PASSWORD';" || exit 1
mysql $MYSQLAUTH -e "GRANT ALL ON $MAGENTO_DB_SCHEMA.* TO '$MAGENTO_DB_USER'@'127.0.0.1' IDENTIFIED BY '$MAGENTO_DB_PASSWORD';" || exit 1
mysql $MYSQLAUTH -e "FLUSH PRIVILEGES;"

echo "## Install packages"
apt-get install -y apache2 libapache2-mod-php7.0 php7.0 php7.0-gd php7.0-mysql php7.0-cli php7.0-curl php7.0-mbstring php7.0-xml php7.0-zip php7.0-intl php7.0-mcrypt php7.0-json curl git composer || exit 1

echo "## Enable Apache rewrite module"
a2enmod rewrite || exit 1

chown -Rf ubuntu. /var/www || exit 1

# Install prestissimo
sudo -u ubuntu composer global require hirak/prestissimo || exit 1

echo "## Create Magento Marketplace credential file"
if [ ! -d /home/ubuntu/.composer ]; then
sudo -u ubuntu mkdir /home/ubuntu/.composer || exit 1
fi
sudo -u ubuntu cat << EOT > /home/ubuntu/.composer/auth.json || exit 1
{
"http-basic": {
"repo.magento.com": {
"username": "$MM_PUBLIC",
"password": "$MM_PRIVATE"
}
}
}
EOT

echo "## Install Magento"
cd /var/www
sudo -u ubuntu composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition ./magento || exit 1
cd magento
echo "## Create magento_umask file"
sudo -u ubuntu cat << EOT > /var/www/magento/magento_umask || exit 1
022
EOT

echo "## bin/magento setup:install"
sudo -u ubuntu php bin/magento setup:install --cleanup-database \
--db-host=localhost \
--db-name=$MAGENTO_DB_SCHEMA \
--db-user=$MAGENTO_DB_USER \
--db-password=$MAGENTO_DB_PASSWORD \
--backend-frontname=$ADMIN_PATH \
--base-url=http://$IP_ADDR/ \
--language=ja_JP \
--timezone=Asia/Tokyo \
--currency=JPY \
--admin-lastname=Admin \
--admin-firstname=Admin \
--admin-email=$ADMIN_EMAIL \
--admin-user=$ADMIN_USER \
--admin-password=$ADMIN_PASSWORD \
--use-secure=0 \
--use-rewrites=1 || exit 1

echo "## Set Magento deploy mode to developer"
sudo -u ubuntu php bin/magento deploy:mode:set developer || exit 1

if [ "$MAGENTO_INSTALL_SAMPLE" = '1' ]; then
echo "## Deploy Sample data"
if [ ! -d /var/www/magento/var/composer_home ]; then
sudo -u ubuntu mkdir /var/www/magento/var/composer_home || exit 1
fi
cat << EOT > /var/www/magento/var/composer_home/auth.json || exit 1
{
"http-basic": {
"repo.magento.com": {
"username": "$MM_PUBLIC",
"password": "$MM_PRIVATE"
}
}
}
EOT
chown ubuntu. /var/www/magento/var/composer_home/auth.json || exit 1
sudo -u ubuntu php bin/magento sampledata:deploy || exit 1
sudo -u ubuntu php bin/magento setup:upgrade || exit 1
fi

echo "## Create Apache virtualhost conf"
cat <<EOT > /etc/apache2/sites-available/000-default.conf || exit 1
<VirtualHost *:80>
DocumentRoot /var/www/magento
<Directory /var/www/magento>
Options Indexes FollowSymLinks
AllowOverride All
Order allow,deny
allow from all
</Directory>
ErrorLog /var/log/apache2/error.log
LogLevel warn
CustomLog /var/log/apache2/access.log combined
</VirtualHost>
EOT
echo "## Apache Restart"
systemctl restart apache2 || exit 1

echo "## Setup Cron Job"
cat <<EOT > /etc/cron.d/magento || exit 1
*/1 * * * * www-data /usr/bin/php /var/www/magento/update/cron.php > /dev/null 2>&1
*/1 * * * * www-data /usr/bin/php /var/www/magento/bin/magento setup:cron:run > /dev/null 2>&1
*/1 * * * * www-data /usr/bin/php /var/www/magento/bin/magento cron:run > /dev/null 2>&1
EOT

echo "## cron Restart"
systemctl restart cron || exit 1
chown -Rf www-data. /var/www/magento/* || exit 1


echo "## Install Postfix"
debconf-set-selections <<< "postfix postfix/mailname string $POSTFIX_HOST_NAME" || exit 1
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'" || exit 1
apt-get install -y postfix mailutils || exit 1


echo "Magentoのインストールが完了しました。" >> /home/ubuntu/info.txt || exit 1

echo "## sent finish email."
cat /home/ubuntu/info2.txt | mail -s "Magento install finished on $IP_ADDR" @@@admin_email@@@
/bin/rm /home/ubuntu/info2.txt || exit 1

echo "## Magento install completely finished!"