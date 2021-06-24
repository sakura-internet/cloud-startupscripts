#!/bin/bash
# @sacloud-name "IPアドレス設定スクリプト for Ubuntu"
# @sacloud-once
# @sacloud-desc-begin
# IPアドレス/プレフィクスを1行ずつ記入してください。
# 1行目がeth1、2行目がeth2、...というように設定されます。
# 空白行や不正な値の場合は、そのインターフェースの設定は行われません。
# 以下の場合はeth1, eth2, eth4にIPアドレスが設定されeth3は設定されません。
# 例) 
# 192.168.10.1/24
# 192.168.20.1/24
#
# 192.168.40.1/24
# @sacloud-desc-end
# @sacloud-textarea heredoc required addresses "IPアドレス/プレフィクス"

_motd() {
  LOG=$(ls /root/.sacloud-api/notes/*log)
  case $1 in
    start)
      echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
    ;;
    fail)
      echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
      exit 1
    ;;
    end)
      cp -f /dev/null /etc/motd
    ;;
 esac
}

set -eux
trap "_motd fail" ERR

_motd start
 
CONFIG_FILE_NAME=10-ipsetting-generated-by-startupscript.yaml
CONFIG_FILE_PATH=/etc/netplan/$CONFIG_FILE_NAME
ADDRESSES=`cat @@@addresses@@@`

cat <<EOF > $CONFIG_FILE_PATH
network:
  renderer: networkd
  version: 2
  ethernets:
EOF

# TODO: eth0もスイッチに繋ぐ場合は0からにする
#	グローバルorスイッチの選択をできるようにする
COUNT=1
echo "$ADDRESSES" | while read address;
do
  ETH="eth$COUNT"
  COUNT=$(( COUNT + 1 ))
  if [ "$address" = "" ]; then
    echo "skip: $ETH"
    continue
  fi
  # TODO: $addressがinvalidなIPのチェック

  cat <<EOF >> $CONFIG_FILE_PATH
    $ETH:
      addresses:
        - $address
      dhcp4: 'no'
      dhcp6: 'no'
EOF
done

netplan apply

_motd end
exit 0