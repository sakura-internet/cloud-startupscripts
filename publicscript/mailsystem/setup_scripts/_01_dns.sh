#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

name=$(hostname | awk -F\. '{print $1}')

#-- ホスト名の設定
hostnamectl set-hostname ${name}.${FIRST_DOMAIN}

#-- DNSレコードの登録
for domain in ${DOMAIN_LIST}
do
  usacloud dns record-add -y --name @ --type A   --ttl 600 --value ${IPADDR} ${domain}
  usacloud dns record-add -y --name @ --type MX  --ttl 600 --value ${FIRST_DOMAIN}. ${domain}
  usacloud dns record-add -y --name @ --type TXT --ttl 600 --value "v=spf1 +ip4:${IPADDR} -all" ${domain}
  if [ "${domain}" = "${FIRST_DOMAIN}" ]
  then
    usacloud dns record-add -y --name ${name} --type A --value ${IPADDR} ${domain}
  fi
  usacloud dns record-add -y --name _dmarc --type TXT --value "v=DMARC1; p=reject; rua=mailto:dmarc-report@${domain}" ${domain}
  usacloud dns record-add -y --name _adsp._domainkey --type TXT --value "dkim=discardable" ${domain}
  if [ "${FIRST_DOMAIN}" = "${domain}" ]
  then
    usacloud dns record-add -y --name autoconfig --type A --value ${IPADDR} ${domain}
  else
    usacloud dns record-add -y --name autoconfig --type CNAME --value autoconfig.${FIRST_DOMAIN}. ${domain}
  fi
done

