#!/bin/bash
# @sacloud-once
# @sacloud-name "IPアドレス設定スクリプト for CentOS"
# @sacloud-desc-begin
# サーバのNICにIPアドレスを割り当てるスクリプトです。
# このスクリプトは、CentOS Stream 8 のみ動作します。
#
# サーバが起動されましたら以下の作業を行って頂く必要がございます。
#   1. サーバをシャットダウンする
#   2. サーバにNICを追加する
#   3. 追加したNICにスイッチと接続する。（スイッチは予めご用意ください。）
#   4. サーバを起動する
#   5. 疎通確認を行う。（pingコマンド等）
#
# @sacloud-desc-end
#
# @sacloud-textarea heredoc required addresses "IPアドレス/プレフィクス"
# @sacloud-require-archive distro-centos distro-ver-8

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

# パラメータ
ADDRESSES=$(cat @@@addresses@@@)

# 各NICにIPアドレス割り当て
COUNT=1
echo "$ADDRESSES" | while read -r address;
do
  ETH="eth$COUNT"
  COUNT=$(( COUNT + 1 ))

  IP=`echo "$address" | awk -F '/' '{print $1}'`
  PREFIX=`echo "$address" | awk -F '/' '{print $2}'`

  # 各NICの設定コンフィグ作成
  cat <<EOF > "/etc/sysconfig/network-scripts/ifcfg-$ETH"
DEVICE=$ETH
BOOTPROTO=static
ONBOOT=yes
TYPE="Ethernet"
IPADDR=$IP
PREFIX=$PREFIX
EOF
done

# 設定の反映
systemctl restart NetworkManager

# 設定完了を表示
echo "* 設定完了"

_motd end
