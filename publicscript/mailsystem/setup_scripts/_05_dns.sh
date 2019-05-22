#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

name=$(hostname | awk -F\. '{print $1}')
usacloud ipv4 ptr-add -y --hostname ${name}.${FIRST_DOMAIN} ${IPADDR}

for domain in ${DOMAIN_LIST}
do
  RECORD=$(cat ${WORKDIR}/keys/${domain}.keys | tr '\n' ' ' | sed -e 's/.*( "//' -e 's/".*"p=/p=/' -e 's/" ).*//')
  usacloud dns record-add -y --name default._domainkey --type TXT --value "${RECORD}" ${domain}
done
