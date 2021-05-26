#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- 逆引き追加
name=$(hostname | awk -F\. '{print $1}')
usacloud ipv4 ptr-add -y --hostname ${name}.${FIRST_DOMAIN} ${IPADDR}
