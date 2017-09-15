#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

cp -p templates/config-v1.1.xml.${TYPE} ${HTTP_DOCROOT}/mail/config-v1.1.xml
sed -i "s/_DOMAIN_/${FIRST_DOMAIN}/g" ${HTTP_DOCROOT}/mail/config-v1.1.xml

