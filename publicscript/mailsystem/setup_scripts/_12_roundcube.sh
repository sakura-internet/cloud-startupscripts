#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

git clone https://github.com/roundcube/roundcubemail.git ${WORKDIR}/git/roundcubemail
cd ${WORKDIR}/git/roundcubemail
base_version=1.4
version=$(git tag | grep "^${base_version}" | sort --version-sort | tail -1)

git checkout ${version}
cp -pr ../roundcubemail ${HTTPS_DOCROOT}/roundcubemail-${version}
ln -s ${HTTPS_DOCROOT}/roundcubemail-${version} ${HTTPS_DOCROOT}/roundcube

#-- roundcube の DB を作成
export HOME=/root
mysql -e "create database roundcubemail character set utf8 collate utf8_bin;"
mysql -e "create user roundcube@localhost identified by 'roundcube';"
mysql -e "grant all privileges ON roundcubemail.* TO roundcube@localhost ;"
mysql -e "flush privileges;"
mysql roundcubemail < ${HTTPS_DOCROOT}/roundcube/SQL/mysql.initial.sql

#-- 必要なPHPのライブラリをインストール
dnf install -y php-{pdo,xml,mbstring,intl,gd,mysqlnd,pear-Auth-SASL,zip} unzip php-pear-Net-SMTP
pear channel-update pear.php.net
pear install -a Mail_mime
#pear install Net_LDAP
pear install Net_LDAP2
pear install Net_Sieve-1.4.4

dnf install -y ImageMagick ImageMagick-devel
pecl channel-update pecl.php.net
yes | pecl install Imagick
echo extension=imagick.so >> /etc/php.d/99-imagick.ini

#-- php-fpm の再起動
systemctl restart php-fpm

#-- roundcube の設定
cat <<'_EOL_'> ${HTTPS_DOCROOT}/roundcube/config/config.inc.php
<?php
$config['db_dsnw'] = 'mysql://roundcube:roundcube@localhost/roundcubemail';
$config['default_host'] = array('_DOMAIN_');
$config['default_port'] = 993;
$config['smtp_server'] = '_DOMAIN_';
$config['smtp_port'] = 465;
$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';
$config['support_url'] = '';
$config['product_name'] = 'Roundcube Webmail';
$config['des_key'] = 'rcmail-!24ByteDESkey*Str';
$config['plugins'] = array('managesieve', 'password', 'archive', 'zipdownload');
$config['managesieve_host'] = 'localhost';
$config['spellcheck_engine'] = 'pspell';
$config['skin'] = 'elastic';
_EOL_

sed -i "s#_DOMAIN_#ssl://${FIRST_DOMAIN}#" ${HTTPS_DOCROOT}/roundcube/config/config.inc.php

cp -p ${HTTPS_DOCROOT}/roundcube/plugins/managesieve/config.inc.php{.dist,}
sed -i -e "s/managesieve_vacation'] = 0/managesieve_vacation'] = 1/" ${HTTPS_DOCROOT}/roundcube/plugins/managesieve/config.inc.php

cp -p ${HTTPS_DOCROOT}/roundcube/plugins/password/config.inc.php{.dist,}

sed -i -e "s/'sql'/'ldap'/" \
  -e "s/'ou=people,dc=example,dc=com'/''/" \
  -e "s/'dc=exemple,dc=com'/''/" \
  -e "s/'uid=%login,ou=people,dc=exemple,dc=com'/'uid=%name,ou=People,%dc'/" \
  -e "s/'(uid=%login)'/'(uid=%name,ou=People,%dc)'/" ${HTTPS_DOCROOT}/roundcube/plugins/password/config.inc.php

chown -R nginx. ${HTTPS_DOCROOT}/roundcubemail-${version}
cd ${HTTPS_DOCROOT}/roundcube
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php
php -r "unlink('composer-setup.php');"
sed -e 's/suggest/require/' -e 's/ required .*/"/' composer.json-dist | perl -ne '{if(/net_ldap3/){chomp; print "$_,\n";}else{print;}}' > composer.json
yes | php composer.phar install --no-dev
bin/install-jsdeps.sh

mv ${HTTPS_DOCROOT}/roundcube/installer ${HTTPS_DOCROOT}/roundcube/_installer

#-- elastic テーマを使用するため、lessc コマンドをインストール
dnf install -y npm
npm install less

cd ${HTTPS_DOCROOT}/roundcube/skins/elastic
export PATH=${PATH}:${HTTPS_DOCROOT}/roundcube/node_modules/less/bin
lessc -x styles/styles.less > styles/styles.css
lessc -x styles/print.less > styles/print.css
lessc -x styles/embed.less > styles/embed.css

cat <<'_EOL_' > /etc/nginx/conf.d/https.d/roundcube.conf
  location ^~ /roundcube {
    location ~ \.php$ {
      try_files $uri =404;
      fastcgi_pass unix:/run/php-fpm/www.sock;
      fastcgi_index index.php;
      fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
      include fastcgi_params;
    }
    location ~ ^/roundcube/(README|INSTALL|LICENSE|CHANGELOG|UPGRADING)$ {
      deny all;
    }

    location ~ ^/roundcube/(bin|SQL)/ {
      deny all;
    }

    # A long browser cache lifetime can speed up repeat visits to your page
    location ~* ^/roundcube/.*\.(jpg|jpeg|gif|png|webp|svg|woff|woff2|ttf|css|js|ico|xml)$ {
      access_log        off;
      log_not_found     off;
      expires           360d;
    }
  }
_EOL_
