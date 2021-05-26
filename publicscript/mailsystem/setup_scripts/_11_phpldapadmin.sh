#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

mkdir -p ${WORKDIR}/git
git clone https://github.com/leenooks/phpLDAPadmin.git ${WORKDIR}/git/phpldapadmin

cd ${WORKDIR}/git/phpldapadmin
version=1.2.6.2
git checkout ${version}

cp -pr ${WORKDIR}/git/phpldapadmin ${HTTPS_DOCROOT}/phpldapadmin-${version}
ln -s ${HTTPS_DOCROOT}/phpldapadmin-${version} ${HTTPS_DOCROOT}/phpldapadmin
cp -p ${HTTPS_DOCROOT}/phpldapadmin/config/config.php{.example,}
chown -R nginx. ${HTTPS_DOCROOT}/phpldapadmin-${version}

#-- 複数ドメインがある場合は、カンマ区切りで追加する
ARRAY_LIST=$(for domain in ${DOMAIN_LIST}
do
  tmpdc=""
  for dc in $(echo "${domain}" | sed 's/\./ /g')
  do
    tmpdc="${tmpdc}dc=${dc},"
  done
  dc=$(echo ${tmpdc} | sed -e 's/,$//' -e "s/^/'/" -e "s/$/'/")
  printf "${dc},"
done | sed 's/,$//')

sed -i -e "531i \$servers->setValue('unique','attrs',array('mail','uidNumber','mailRoutingaddress','mailAlternateAddress'));" \
  -e "472i \$servers->setValue('login','anon_bind',false);" \
  -e "305i \$servers->setValue('server','base',array(${ARRAY_LIST}));" ${HTTPS_DOCROOT}/phpldapadmin/config/config.php

#-- 使用しないテンプレートを移動
mkdir ${HTTPS_DOCROOT}/phpldapadmin/templates/creation_backup
for x in courierMailAccount.xml courierMailAlias.xml mozillaOrgPerson.xml sambaDomain.xml sambaGroupMapping.xml sambaMachine.xml sambaSamAccount.xml dNSDomain.xml
do
  mv ${HTTPS_DOCROOT}/phpldapadmin/templates/creation/${x} ${HTTPS_DOCROOT}/phpldapadmin/templates/creation_backup
done
