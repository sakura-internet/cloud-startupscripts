#!/bin/bash

# @sacloud-name "baserCMS"
# @sacloud-once
#
# @sacloud-require-archive distro-centos distro-ver-7.*
#
# @sacloud-desc-begin
#   CakePHPで動作する、Webサイト開発プラットフォームとして最適な国産CMS「baserCMS」をインストールします。
#	デフォルトでは、テーマ「bc_sample」を適用した状態でインストールしますので、
#	インストール完了後、適宜、テーマ管理よりテーマを変更して利用してください。
#
#   サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
#   http://サーバのIPアドレス/
#
#   管理者ページへは、以下のようなURLでアクセスしてください。
#   http://サーバのIPアドレス/admin
#
#	※ アクセスするURLは、デフォルトでサーバのIPアドレスとなっていますが、
#	  独自ドメイン利用時、「baserCMS サイトのURL」を設定すると独自ドメインのURLでアクセスする事ができます。
#   ※ このスクリプトは、CentOS7.Xで動作します
# @sacloud-desc-end
#
# @sacloud-text required shellarg maxlen=60 user_name "baserCMS 管理ユーザ名"
# @sacloud-password required shellarg maxlen=60 user_pass "baserCMS 管理ユーザのパスワード"
# @sacloud-text required shellarg maxlen=254 ex=your.name@example.jp user_mail "baserCMS 管理ユーザのメールアドレス"
# @sacloud-text shellarg maxlen=254 ex=http://example.jp site_url "baserCMS サイトのURL（省略するとサーバのIPアドレスになります）"

# install packages
yum -y install expect httpd-devel mod_ssl php php-devel php-pear mariadb-server php-mbstring php-xml php-gd php-mysql|| exit 1

# init variables
MYSQLPASSWORD=$(mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2)
DBNAME="baser_$(mkpasswd -l 10 -C 0 -s 0)"
DBPASS=$(mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2)
ZIPFILE=$(mktemp)
SITE_URL=@@@site_url@@@

# init SITE_URL
if [ "x$SITE_URL" = "x" ]; then
  SITE_URL="http://$(ip -f inet -o addr show eth0| cut -d\  -f 7| cut -d/ -f 1)/"
fi

# set php timezone
cat >/etc/php.d/timezone.ini <<EOL
date.timezone = "Asia/Tokyo"
EOL

# install mysql/mariadb
systemctl start mariadb
for i in {1..5}; do
  sleep 1
  systemctl status mariadb >/dev/null 2>&1 && break
  [ "$i" -lt 5 ] || exit 1
done
systemctl enable mariadb

# init mysql/mariadb
/usr/bin/mysqladmin -u root password "$MYSQLPASSWORD" || exit 1
cat <<EOL > /root/.my.cnf
[client]
host     = localhost
user     = root
password = $MYSQLPASSWORD
socket   = /var/lib/mysql/mysql.sock
EOL
chmod 600 /root/.my.cnf

# init database for baserCMS
mysql --defaults-file=/root/.my.cnf <<-EOL
CREATE DATABASE IF NOT EXISTS $DBNAME;
GRANT ALL ON $DBNAME.* TO '$DBNAME'@'localhost' IDENTIFIED BY '$DBPASS';
FLUSH PRIVILEGES;
EOL

# install apache/httpd
cat <<EOL > /etc/httpd/conf.d/$DBNAME.conf
<VirtualHost *:80>
DocumentRoot /var/www/$DBNAME
AllowEncodedSlashes On
<Directory />
    Options FollowSymLinks
    AllowOverride None
</Directory>
<Directory "/var/www/$DBNAME">
    Options FollowSymLinks MultiViews ExecCGI
    AllowOverride All
    Order allow,deny
    allow from all
</Directory>
</VirtualHost>
EOL

systemctl start httpd
for i in {1..5}; do
  sleep 1
  systemctl status httpd >/dev/null 2>&1 && break
  [ "$i" -lt 5 ] || exit 1
done
systemctl enable httpd

# fetch baserCMS latest package
curl -L https://basercms.net/packages/download/basercms/latest_version >$ZIPFILE
unzip -d /var/www $ZIPFILE
mv /var/www/basercms /var/www/$DBNAME

# init baserCMS
/var/www/$DBNAME/app/Console/cake bc_manager install \
  "$SITE_URL" \
  mysql \
  @@@user_name@@@ \
  @@@user_pass@@@ \
  @@@user_mail@@@ \
  --host localhost \
  --database "$DBNAME" \
  --port 3306 \
  --login "$DBNAME" \
  --password "$DBPASS" \
  --data 'bc_sample.default'

chown -R apache:apache /var/www/$DBNAME

# set firewalld
firewall-cmd --permanent --add-service http --zone=public
firewall-cmd --reload

# end
