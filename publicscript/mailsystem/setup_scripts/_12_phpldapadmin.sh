#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- phpldapadmin本家は php7.x に対応していない為、 fork されたものを clone する
mkdir -p ${WORKDIR}/git
git clone https://github.com/breisig/phpLDAPadmin.git ${WORKDIR}/git/phpldapadmin

cp -pr ${WORKDIR}/git/phpldapadmin ${HTTPS_DOCROOT}/phpldapadmin
cp -p ${HTTPS_DOCROOT}/phpldapadmin/config/config.php{.example,}
chown -R nginx. ${HTTPS_DOCROOT}/phpldapadmin

#-- 複数ドメインがある場合は、カンマ区切りで追加する
ARRAY_LIST=$(for DOMAIN in ${DOMAIN_LIST}
do
        tmpdc=""
        for dc in $(echo "${DOMAIN}" | sed 's/\./ /g')
        do
                tmpdc="${tmpdc}dc=${dc},"
        done
        dc=$(echo ${tmpdc} | sed -e 's/,$//' -e "s/^/'/" -e "s/$/'/")
        printf "${dc},"
done | sed 's/,$//')

sed -i -e "301i \$servers->setValue('server','base',array(${ARRAY_LIST}));" ${HTTPS_DOCROOT}/phpldapadmin/config/config.php

#-- 使用しないテンプレートを移動
mkdir ${HTTPS_DOCROOT}/phpldapadmin/templates/creation_backup
for x in courierMailAccount.xml courierMailAlias.xml mozillaOrgPerson.xml sambaDomain.xml sambaGroupMapping.xml sambaMachine.xml sambaSamAccount.xml
do
	mv ${HTTPS_DOCROOT}/phpldapadmin/templates/creation/${x} ${HTTPS_DOCROOT}/phpldapadmin/templates/creation_backup
done
