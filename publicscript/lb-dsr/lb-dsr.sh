#!/bin/bash
# @sacloud-name "lb-dsr"
# @sacloud-once
# @sacloud-desc-begin
# ロードバランス対象のサーバの初期設定を自動化するためのスクリプトです。
# このスクリプトは、以下のアーカイブでのみ動作します
#  - CentOS 6.X
#  - CentOS 7.X
#  - SiteGuard Lite Ver3.X UpdateX (CentOS 6.X)
#  - SiteGuard Lite Ver3.X UpdateX (CentOS 7.X)
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-6.*
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-require-archive pkg-siteguard
# @sacloud-text required shellarg maxlen=20 para1 "ロードバランサーのVIP"

PARA1=@@@para1@@@
PARA2="net.ipv4.conf.all.arp_ignore = 1"
PARA3="net.ipv4.conf.all.arp_announce = 2"
PARA4="DEVICE=lo:0"
PARA5="IPADDR="$PARA1
PARA6="NETMASK=255.255.255.255"

VERSION=$(rpm -q centos-release --qf %{VERSION}) || exit 1

case "$VERSION" in
  6 ) ;;
  7 ) firewall-cmd --add-service=http --zone=public --permanent
      firewall-cmd --reload;;
  * ) ;;
esac

cp --backup /etc/sysctl.conf /tmp/ || exit 1

echo $PARA2 >> /etc/sysctl.conf
echo $PARA3 >> /etc/sysctl.conf
sysctl -p 1>/dev/null

cp --backup /etc/sysconfig/network-scripts/ifcfg-lo:0 /tmp/ 2>/dev/null

touch /etc/sysconfig/network-scripts/ifcfg-lo:0
echo $PARA4 > /etc/sysconfig/network-scripts/ifcfg-lo:0
echo $PARA5 >> /etc/sysconfig/network-scripts/ifcfg-lo:0
echo $PARA6 >> /etc/sysconfig/network-scripts/ifcfg-lo:0

ifup lo:0 || exit 1

exit 0