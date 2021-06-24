#!/bin/bash
# @sacloud-name "IPアドレス設定スクリプト for Ubuntu"
# @sacloud-require-archive distro-ubuntu distro-ver-20.04.*
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

# 1 <= $prefix <= 32 であるか
function is_valid_prefix() {
	prefix=$1

	# 数値かどうか
	if [[ ! "$prefix" =~ ^[0-9]+$ ]]; then
		echo "invalid"
    return
	fi

	# $prefix < 1
	if [ "$prefix" -lt 1 ]; then
		echo "invalid"
    return
	fi

	# $prefix > 32
	if [ "$prefix" -gt 32 ]; then
		echo "invalid"
    return
	fi

  echo "valid"
  return
}

# 0 <= $octet <= 255 であるか
function is_valid_ip_octet() {
	octet=$1

	# 数値かどうか
	if [[ ! "$octet" =~ ^[0-9]+$ ]]; then
    echo "invalid"
		return
	fi

	# $octet < 0
	if [ "$octet" -lt 0 ]; then
    echo "invalid"
		return
	fi
	# $octet > 255
	if [ "$octet" -gt 255 ]; then
    echo "invalid"
		return
	fi
  echo "valid"
	return
}

function is_valid_ip(){
	ipprefix=$1

	# ipaddress/prefixを分割
	read -r -a octets <<EOF
$(echo "$ipprefix" | awk -F '/' '{printf $1}' | sed -e "s/\./ /g")
EOF
	prefix=$(echo "$ipprefix" | awk -F '/' '{printf $2}')

	# プレフィクスが1~32かどうかチェックする
	ret=$(is_valid_prefix "$prefix")
	if [ "$ret" = "invalid" ]; then
		echo "invalid"
    return
	fi

	count=0
	# 各オクテットが0~255の数値かどうかをチェックする
	for octet in "${octets[@]}"
	do
		ret=$(is_valid_ip_octet "$octet")
		if [ "$ret" = "invalid" ]; then
      echo "invalid"
			return
		fi
		count=$(( count + 1 ))
	done

	# 4オクテットなら成功
	if [ "$count" = "4" ]; then
    echo "valid"
		return
	fi

	# 4オクテットではないので失敗
  echo "invalid"
	return
}

_motd start
 
CONFIG_FILE_NAME=10-ipsetting-generated-by-startupscript.yaml
CONFIG_FILE_PATH=/etc/netplan/$CONFIG_FILE_NAME
ADDRESSES=$(cat @@@addresses@@@)

cat <<EOF > $CONFIG_FILE_PATH
network:
  renderer: networkd
  version: 2
  ethernets:
EOF

COUNT=1
echo "$ADDRESSES" | while read -r address;
do
  ETH="eth$COUNT"
  COUNT=$(( COUNT + 1 ))

  ret=$(is_valid_ip "$address")
  if [ "$ret" = "invalid" ]; then
    echo "$ETH: skip. $address"
    continue
  fi

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