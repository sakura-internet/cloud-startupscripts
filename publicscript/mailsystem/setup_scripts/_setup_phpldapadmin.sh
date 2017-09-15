#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

yum install -y phpldapadmin

ln -s /usr/share/phpldapadmin ${HTTPS_DOCROOT}/phpldapadmin
chgrp nginx /etc/phpldapadmin/config.php
sed -i "s/.*('login','attr','uid')/\$servers->setValue('login','attr','dn')/" /etc/phpldapadmin/config.php
sed -i "s/.*('appearance','show_create',true)/\$servers->setValue('appearance','show_create',true)/" /etc/phpldapadmin/config.php
sed -i "s/127.0.0.1/${LDAP_MASTER}/" /etc/phpldapadmin/config.php

sed -i "s/.*('server','base',array(''))/\$servers->setValue('server','base',array(_BASE_))/" /etc/phpldapadmin/config.php

BASE=""
for ZONE in ${DOMAIN_LIST}
do
	DC=$(echo ${ZONE} | sed -e 's/\./,dc=/g' -e 's/^/dc=/')
	BASE="${BASE}'${DC}',"
done
BASE=$(echo ${BASE} | sed 's/,$//')

sed -i "s/_BASE_/${BASE}/" /etc/phpldapadmin/config.php

mkdir ${HTTPS_DOCROOT}/phpldapadmin/templates/creation_backup
for x in courierMailAccount.xml courierMailAlias.xml mozillaOrgPerson.xml sambaDomain.xml sambaGroupMapping.xml sambaMachine.xml sambaSamAccount.xml
do
	mv -f ${HTTPS_DOCROOT}/phpldapadmin/templates/creation/${x} ${HTTPS_DOCROOT}/phpldapadmin/templates/creation_backup/
done

sed -i "s/.*postalAddress.*telephoneNumber.*/\t\t\t'default'=>array('mailRoutingAddress','mailLocalAddress','mailHost','sendmailMTAHost'));/" ${HTTPS_DOCROOT}/phpldapadmin/lib/config_default.php

systemctl restart php-fpm
