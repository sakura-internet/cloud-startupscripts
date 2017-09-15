#!/bin/bash
set -e

source $(dirname $0)/../config.source
source $(dirname $0)/_startup_function.lib
echo "---- $0 ----"

HOST=$(hostname | awk -F\. '{print $1}')
ZONE=$(jq -r ".Zone.Name" /root/.sacloud-api/server.json)
BASE=https://secure.sakura.ad.jp/cloud/zone/${ZONE}/api/cloud/1.1
API=${BASE}/ipaddress/${IPADDR}
PTRJS=ptr.json
cat <<_EOL_> ${PTRJS}
{
	"IPAddress": { "HostName": "${HOST}.${FIRST_DOMAIN}" }
}
_EOL_

curl -s --user "${KEY}" -X PUT -d "$(cat ${PTRJS} | jq -c .)" ${API} |jq "."
PRET=$(curl -s --user "${KEY}" -X GET ${API} | jq -r "select(.IPAddress.HostName == \"${HOST}.${FIRST_DOMAIN}\") | .is_ok")

if [ "${PRET}x" != "truex" ]
then
	echo "逆引きの登録に失敗"
	_motd fail
fi
