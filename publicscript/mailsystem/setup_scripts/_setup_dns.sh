#!/bin/bash
set -e

source $(dirname $0)/../config.source
source $(dirname $0)/_startup_function.lib
echo "---- $0 ----"

mkdir -p ${WORKDIR}/dns

ZONE=$(jq -r ".Zone.Name" /root/.sacloud-api/server.json)
BASE=https://secure.sakura.ad.jp/cloud/zone/${ZONE}/api/cloud/1.1/commonserviceitem/
HOST=$(hostname)

for ZONE in ${DOMAIN_LIST}
do
	# check zone
	_check_sacloud_zone ${ZONE}

	RESOURCEID=$(curl -s --user "${KEY}" ${BASE} | jq -r ".CommonServiceItems[] | select(contains({Status: {Zone: \"${ZONE}\"}})) | .ID")
	APIURL=${BASE}${RESOURCEID}
	DKIMKEY=$(cat /etc/opendkim/keys/default.txt | tr '\n' ' ' | sed -e 's/.*( "//' -e 's/".*"p=/p=/' -e 's/" ).*//')

	cat <<-_EOL_> ${WORKDIR}/dns/${ZONE}.json
	{
	  "CommonServiceItem": {
	    "Settings": {
	      "DNS":  {
	        "ResourceRecordSets": [
	          { "Name": "@", "Type": "A", "RData": "${IPADDR}" },
	          { "Name": "@", "Type": "MX", "RData": "10 ${FIRST_DOMAIN}." },
	          { "Name": "@", "Type": "TXT", "RData": "v=spf1 +ip4:${IPADDR} -all" },
	          { "Name": "${HOST}", "Type": "A", "RData": "${IPADDR}" },
	          { "Name": "autoconfig", "Type": "A", "RData": "${IPADDR}" },
	          { "Name": "_dmarc", "Type": "TXT", "RData": "v=DMARC1; p=reject; rua=mailto:admin@${ZONE}" },
	          { "Name": "_adsp._domainkey", "Type": "TXT", "RData": "dkim=discardable" },
	          { "Name": "default._domainkey", "Type": "TXT", "RData": "${DKIMKEY}" }
	        ]
	      }
	    }
	  }
	}
	_EOL_

	for x in @:A @:MX @:TXT ${HOST}:A autoconfig:A _dmarc:TXT _adsp._domainkey:TXT default._domainkey:TXT
	do
		NAME=$(echo ${x} | awk -F: '{print $1}')
		RECODE=$(echo ${x} | awk -F: '{print $2}')
		if [ "${NAME}" = "@" ]
		then
			if [ $(_check_exist_recode ${ZONE} ${RECODE}) -eq 1 ]
			then
				echo "該当のレコードはDNSに既に登録されています"
				_motd fail
			fi
		fi
	done

	POSTDATA=$(cat ${WORKDIR}/dns/${ZONE}.json | jq -c .)
	curl -s --user "${KEY}" -X PUT -d "${POSTDATA}" ${APIURL} | jq "."
done

hostnamectl set-hostname ${HOST}.${FIRST_DOMAIN}
sed -i 's/^::1/#::1/' /etc/hosts

