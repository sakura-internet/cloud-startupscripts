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
# @sacloud-text required ETH1_IP_ADDRESS "eth1に割り当てるローカルIPアドレス/プレフィックス" ex="192.168.1.1/24"
# @sacloud-text ETH2_IP_ADDRESS "eth2に割り当てるローカルIPアドレス/プレフィックス" ex="192.168.2.1/24"
# @sacloud-require-archive distro-centos distro-ver-8.*

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
ETH1_IP_ADDRESS=@@@ETH1_IP_ADDRESS@@@
ETH2_IP_ADDRESS=@@@ETH2_IP_ADDRESS@@@

# eth1のIPアドレスの割り当て
echo "* eth1のIPアドレスの割り当て"

ETH1_IP=`echo "$ETH1_IP_ADDRESS" | awk -F '/' '{print $1}'`
ETH1_PREFIX=`echo "$ETH1_IP_ADDRESS" | awk -F '/' '{print $2}'`

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
TYPE="Ethernet"
IPADDR=$ETH1_IP
PREFIX=$ETH1_PREFIX
EOF

# eth2のIPアドレスの割り当て
if [ -n "$ETH2_IP_ADDRESS" ]; then
  echo "* eth2のIPアドレスの割り当て"

  ETH2_IP=`echo "$ETH2_IP_ADDRESS" | awk -F '/' '{print $1}'`
  ETH2_PREFIX=`echo "$ETH2_IP_ADDRESS" | awk -F '/' '{print $2}'`

  cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth2
DEVICE=eth2
BOOTPROTO=static
ONBOOT=yes
TYPE="Ethernet"
IPADDR=$ETH2_IP
PREFIX=$ETH2_PREFIX
EOF
fi

# 設定の反映
systemctl restart NetworkManager

# 設定完了を表示
echo "* 設定完了"

_motd end
