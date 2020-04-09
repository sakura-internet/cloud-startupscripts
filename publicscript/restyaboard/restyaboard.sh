#!/bin/bash
#
# @sacloud-name "Restyaboard"
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトは Restyaboard をセットアップします
# (CentOS7.X でのみ動作します)
# サーバ作成後はブラウザより「http://サーバのIPアドレス/」でアクセスすることができます
# 管理ユーザは Username:admin Password:restya です。
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-7

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

_motd start
set -ex
trap '_motd fail' ERR

# 必要パッケージのインストール
yum update -y
yum install -y epel-release
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
yum install -y php72-php php72-php-{fpm,devel,cli,curl,pgsql,mbstring,ldap,pear,imap,xml,imagick,pecl-geoip} ImageMagick GeoIP-devel nginx expect
yum install -y https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum install -y postgresql96-server postgresql96-contrib

# php の設定
sed -i 's/= apache/= nginx/' /etc/opt/remi/php72/php-fpm.d/www.conf
sed -i -e 's/^;date.timezone =/date.timezone = Asia\/Tokyo/' \
	-e 's/^;cgi.fix_pathinfo=1/;cgi.fix_pathinfo=0/' /etc/opt/remi/php72/php.ini

# Postgresqlの設定
export PGSETUP_INITDB_OPTIONS="--encoding=UTF-8 --no-locale"
/usr/pgsql-9.6/bin/postgresql96-setup initdb

sed -i -e 's/^local.*/local all all trust/' \
	-e "s/ident$/md5/" /var/lib/pgsql/9.6/data/pg_hba.conf

systemctl enable postgresql-9.6 php72-php-fpm nginx
systemctl start postgresql-9.6 php72-php-fpm nginx

# Restyaboard 用のデータベース作成
su - postgres -c "psql <<_EOL_
CREATE USER rb_user WITH PASSWORD 'rb_pass';
CREATE DATABASE restyaboard OWNER rb_user ENCODING 'UTF8' TEMPLATE template0;
GRANT ALL PRIVILEGES ON DATABASE restyaboard TO rb_user;
_EOL_
"

# Restyaboardのインストールとセットアップ
DOCROOT=/usr/share/nginx/html
VERSION=0.6.4

cd ${DOCROOT}
curl -L -O https://github.com/RestyaPlatform/board/releases/download/v${VERSION}/board-v${VERSION}.zip
unzip board-v${VERSION}.zip -d board-v${VERSION}
ln -s board-v${VERSION} board
rm -f board-v${VERSION}.zip

psql -d restyaboard -f ${DOCROOT}/board/sql/restyaboard_with_empty_data.sql -U rb_user
sed -i -e "s#define('R_DB_USER', 'restya');#define('R_DB_USER', 'rb_user');#" \
	-e "s#define('R_DB_PASSWORD', 'hjVl2\!rGd');#define('R_DB_PASSWORD', 'rb_pass');#" \
	-e "s#define('R_DB_NAME', 'restyaboard');#define('R_DB_NAME', 'restyaboard');#" ${DOCROOT}/board/server/php/config.inc.php

#### nginxの設定
sed -i 's/^ *listen/#        listen/' /etc/nginx/nginx.conf
cp ${DOCROOT}/board/restyaboard.conf /etc/nginx/conf.d
sed -i -e "s#/usr/share/nginx/html#${DOCROOT}/board#" \
	-e "s#unix:/run/php/php7.0-fpm.sock#127.0.0.1:9000#" /etc/nginx/conf.d/restyaboard.conf

chown -R nginx. ${DOCROOT}/board/
chmod -R go+w ${DOCROOT}/board/{media,client/img,tmp/cache}
chmod -R 755 ${DOCROOT}/board/server/php/shell/*.sh

#### cronの設定
PHPCONF=/opt/remi/php72/enable
cat << _EOF_ >/etc/cron.d/restyaboard
*/5 * * * * root source ${PHPCONF} && ${DOCROOT}/board/server/php/shell/instant_email_notification.sh 2>/dev/null
0 * * * * root source ${PHPCONF} && ${DOCROOT}/board/server/php/shell/periodic_email_notification.sh 2>/dev/null
*/30 * * * * root source ${PHPCONF} && ${DOCROOT}/board/server/php/shell/imap.sh 2>/dev/null
*/5 * * * * root source ${PHPCONF} && ${DOCROOT}/board/server/php/shell/webhook.sh 2>/dev/null
*/5 * * * * root source ${PHPCONF} && ${DOCROOT}/board/server/php/shell/card_due_notification.sh 2>/dev/null
_EOF_

firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload

shutdown -r 1

_motd end

