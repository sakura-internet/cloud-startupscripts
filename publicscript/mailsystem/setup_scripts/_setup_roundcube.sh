#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

yum install -y php-mcrypt php-mysql php-xml php-pear php-mbstring php-intl php-pecl-imagick php-gd php-pear-Mail-mimeDecode php-kolab-net-ldap3 php-pear-Net-IDNA2 php-pear-Auth-SASL php-pear-Net-SMTP php-pear-Net-Sieve
sed -i 's/^;default_charset/default_charset/' /etc/php.ini
sed -i "s/^;date.timezone.*/date.timezone = 'Asia\/Tokyo'/" /etc/php.ini
sed -i 's/^post_max_size =.*/post_max_size = 20M/' /etc/php.ini
sed -i 's/^upload_max_filesize =.*/upload_max_filesize = 20M/' /etc/php.ini

cp templates/config.inc.php.roundcube /tmp/config.inc.php.roundcube
cp templates/config.inc.php.password /tmp/config.inc.php.password

mkdir -p ${WORKDIR}/build
cd ${WORKDIR}/build
git clone https://github.com/roundcube/roundcubemail.git
cd roundcubemail
RV=$(git for-each-ref --sort=-taggerdate --format='%(tag)' refs/tags | grep -m 1 "1\.3\.")
git checkout ${RV}
cp -pr ../roundcubemail ${HTTPS_DOCROOT}/roundcubemail-${RV}
ln -s ${HTTPS_DOCROOT}/roundcubemail-${RV} ${HTTPS_DOCROOT}/roundcube

export HOME=/root
mysql -e "create database roundcubemail character set utf8 collate utf8_bin;"
mysql -e "grant all on roundcubemail.* to roundcube@localhost identified by 'roundcube';"
mysql -e "FLUSH PRIVILEGES;"
mysql roundcubemail < ${HTTPS_DOCROOT}/roundcube/SQL/mysql.initial.sql

systemctl restart php-fpm

mv /tmp/config.inc.php.roundcube ${HTTPS_DOCROOT}/roundcube/config/config.inc.php
mv /tmp/config.inc.php.password ${HTTPS_DOCROOT}/roundcube/plugins/password/config.inc.php
chown -R nginx. ${HTTPS_DOCROOT}/roundcubemail-${RV}

cp -p ${HTTPS_DOCROOT}/roundcube/plugins/managesieve/config.inc.php.dist ${HTTPS_DOCROOT}/roundcube/plugins/managesieve/config.inc.php

sed -i "s#_DOMAIN_#ssl://${FIRST_DOMAIN}#" ${HTTPS_DOCROOT}/roundcube/config/config.inc.php

cd ${HTTPS_DOCROOT}/roundcube/bin
./install-jsdeps.sh

mv ${HTTPS_DOCROOT}/roundcube/installer ${HTTPS_DOCROOT}/roundcube/_installer
