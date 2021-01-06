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
mysql -e "CREATE DATABASE roundcubemail CHARACTER SET utf8 collate utf8_bin;"
mysql -e "GRANT ALL PRIVILEGES ON roundcubemail.* TO roundcube@localhost IDENTIFIED BY 'roundcube';"
mysql roundcubemail < ${HTTPS_DOCROOT}/roundcube/SQL/mysql.initial.sql

#-- 必要なPHPのライブラリをインストール
yum install -y php73-php-{pdo,xml,pear,mbstring,intl,pecl-imagick,gd,mysqlnd,pspell}
yum install -y php-pear-Mail-mimeDecode php-kolab-net-ldap3 php-pear-Net-IDNA2 php-pear-Auth-SASL php-pear-Net-SMTP php-pear-Net-Sieve

#-- php-fpm の再起動
systemctl restart php73-php-fpm

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
cd ${HTTPS_DOCROOT}/roundcube/bin
./install-jsdeps.sh

mv ${HTTPS_DOCROOT}/roundcube/installer ${HTTPS_DOCROOT}/roundcube/_installer

#-- elastic テーマを使用するため、lessc コマンドをインストール
yum install -y npm
npm install -g less@3.13.1

cd ${HTTPS_DOCROOT}/roundcube/skins/elastic
lessc -x styles/styles.less > styles/styles.css
lessc -x styles/print.less > styles/print.css
lessc -x styles/embed.less > styles/embed.css

