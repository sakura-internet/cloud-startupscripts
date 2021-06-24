#!/bin/bash
# @sacloud-once
# @sacloud-name "IPアドレス設定スクリプト"
# @sacloud-desc 説明文
#
# @sacloud-text required ETH1_IP_ADDRESS "eth1に割り当てるローカルIPアドレス/プレフィックス" ex="192.168.0.1/24"
# @sacloud-text ETH2_IP_ADDRESS "eth2に割り当てるローカルIPアドレス/プレフィックス" ex="192.168.1.1/24"


set -eux

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