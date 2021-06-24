#!/bin/bash
# @sacloud-once
# @sacloud-name "IPアドレス設定スクリプト"
# @sacloud-desc 説明文
#
# @sacloud-text required ETH1_IP_ADDRESS "eth1に割り当てるローカルIPアドレス/プレフィックス" ex="192.168.0.1/24"
# @sacloud-text ETH2_IP_ADDRESS "eth2に割り当てるローカルIPアドレス/プレフィックス" ex="192.168.1.1/24"
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
nmcli connection add type ethernet con-name "System eth1" ifname eth1
nmcli connection modify "System eth1" connection.autoconnect yes ipv4.method manual ipv4.addresses "${ETH1_IP_ADDRESS}"
nmcli connection up "System eth1"

# eth2のIPアドレスの割り当て
if [ -n "$ETH2_IP_ADDRESS" ]; then
    echo "* eth2のIPアドレスの割り当て"
    nmcli connection add type ethernet con-name "System eth2" ifname eth2
    nmcli connection modify "System eth2" connection.autoconnect yes ipv4.method manual ipv4.addresses "${ETH2_IP_ADDRESS}"
    nmcli connection up "System eth2"
fi

# 設定完了を表示
echo "* 設定完了"

_motd end
