#!/bin/bash
#
# @sacloud-once
# @sacloud-name "IPアドレス設定スクリプト for CentOS"
# @sacloud-desc-begin
# サーバのNICにIPアドレスを割り当てるスクリプトです。
# 以下の内容で設定されます。
#   * /etc/sysconfig/network-scripts/ifcfg-eth* で制御
#   * DHCPを使用しない
#   * OS起動時、リンクアップ
#   * ゲートウェイ指定なし
#
# このスクリプトは、CentOS 7, CentOS 8, CentOS Stream 8 で動作します。
#
#
# 以下の入力欄には、IPアドレス/プレフィックスを1行ずつ記入してください。
# 1行目がeth1、2行目がeth2...というように設定されます。
# 空白行や不正な値の場合は、そのインターフェースの設定は行われません。
# 以下の場合はeth1, eth2, eth4にIPアドレスが設定され、eth3には設定されません。
# 例)
#   192.168.10.1/24
#   192.168.20.1/24
#
#   192.168.40.1/24
#
#
# サーバ作成前に以下の作業を行って頂く必要がございます。
#   1. こちらのページ下部にある「作成後すぐに起動」のチェックを外して作成する
#   2. サーバにNICを追加する
#   3. 追加したNICにスイッチと接続する。（スイッチは予めご用意ください。）
#   4. サーバを起動する
#   5. 疎通確認を行う。（pingコマンド等）
#
# @sacloud-desc-end
#
# @sacloud-textarea heredoc required addresses "IPアドレス/プレフィックス" ex="192.168.1.1/24"
#
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-require-archive distro-centos distro-ver-8.*
# @sacloud-require-archive distro-centos distro-ver-8
#

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

_motd start
set -eux
trap '_motd fail' ERR

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

# パラメータ
ADDRESSES=$(cat @@@addresses@@@)

# 各NICにIPアドレス割り当て
COUNT=1
echo "$ADDRESSES" | while read -r address;
do
  DEVICE="eth$COUNT"
  COUNT=$(( COUNT + 1 ))

  ret=$(is_valid_ip "$address")
  if [ "$ret" = "invalid" ]; then
    echo "$DEVICE: skip. $address"
    continue
  fi

  IP=`echo "$address" | awk -F '/' '{print $1}'`
  PREFIX=`echo "$address" | awk -F '/' '{print $2}'`

  # 各NICのconfigファイル作成
  cat <<EOF > "/etc/sysconfig/network-scripts/ifcfg-$DEVICE"
DEVICE=$DEVICE
BOOTPROTO=static
ONBOOT=yes
TYPE="Ethernet"
IPADDR=$IP
PREFIX=$PREFIX
EOF
done

# 設定完了を表示
echo "* 設定完了"

_motd end
