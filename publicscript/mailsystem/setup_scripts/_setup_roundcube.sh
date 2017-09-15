#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

yum install -y roundcubemail php-mcrypt php-mysql
sed -i 's/^;default_charset/default_charset/' /etc/php.ini
sed -i "s/^;date.timezone.*/date.timezone = 'Asia\/Tokyo'/" /etc/php.ini
sed -i 's/^post_max_size =.*/post_max_size = 20M/' /etc/php.ini
sed -i 's/^upload_max_filesize =.*/upload_max_filesize = 20M/' /etc/php.ini

export HOME=/root
mysql -e "create database roundcubemail character set utf8 collate utf8_bin;"
mysql -e "grant all on roundcubemail.* to roundcube@localhost identified by 'roundcube';"
mysql -e "FLUSH PRIVILEGES;"
mysql roundcubemail < /usr/share/roundcubemail/SQL/mysql.initial.sql

systemctl restart php-fpm

ln -s /usr/share/roundcubemail ${HTTPS_DOCROOT}/roundcube
mkdir ${HTTPS_DOCROOT}/roundcube/{temp,logs}
chown -R nginx. /usr/share/roundcubemail

cp templates/config.inc.php.roundcube /etc/roundcubemail/config.inc.php
chgrp -R nginx /var/{lib,log}/roundcubemail /etc/roundcubemail

cp templates/config.inc.php.password ${HTTPS_DOCROOT}/roundcube/plugins/password/config.inc.php
chown nginx. ${HTTPS_DOCROOT}/roundcube/plugins/password/config.inc.php

cp -p ${HTTPS_DOCROOT}/roundcube/plugins/managesieve/config.inc.php.dist ${HTTPS_DOCROOT}/roundcube/plugins/managesieve/config.inc.php

sed -i "s#_DOMAIN_#ssl://${FIRST_DOMAIN}#" /etc/roundcubemail/config.inc.php

cd ${HTTPS_DOCROOT}/roundcube/plugins/
git clone https://github.com/messagerie-melanie2/Roundcube-Plugin-Mobile.git
git clone https://github.com/messagerie-melanie2/Roundcube-Plugin-JQuery-Mobile.git
mv Roundcube-Plugin-JQuery-Mobile jquery_mobile
mv Roundcube-Plugin-Mobile mobile

chown nginx. jquery_mobile mobile

cd ../skins
git clone https://github.com/messagerie-melanie2/Roundcube-Skin-Melanie2-Larry-Mobile.git
mv Roundcube-Skin-Melanie2-Larry-Mobile melanie2_larry_mobile
chown nginx. melanie2_larry_mobile

mv ${HTTPS_DOCROOT}/roundcube/installer ${HTTPS_DOCROOT}/roundcube/_installer
