#!/bin/bash
# @sacloud-once
# @sacloud-name "GNOME-xrdp"
# @sacloud-require-archive distro-centos distro-ver-7.*
#
# @sacloud-desc-begin
#   GNOMEデスクトップ環境とTigerVNC、xrdp をインストールし、リモートデスクトップ接続をできるようにします。
#   （このスクリプトは、CentOS7.Xでのみ動作します）
# @sacloud-desc-end
# @sacloud-textarea heredoc ADDR "xrdp に接続するクライアントのIPアドレス(ipv4)を制限する場合は、1行に1つIPアドレスを入力してください。" ex="127.0.0.1"

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

# ready for startup script
_motd start
set -e
trap '_motd fail' ERR

# Install nginx,mariadb,php
yum -y install yum-utils
yum -y install epel-release
yum-config-manager --enable epel

# install XRDP
yum -y install xrdp
yum -y install tigervnc-server
# install GNOME
yum -y groups install "GNOME Desktop"
systemctl set-default graphical.target

# XRDP color change: 32bit -> 64bit
sed -i -e 's/max_bpp=32/max_bpp=24/g' /etc/xrdp/xrdp.ini

# install and config japanese environment
yum -y install ibus-kkc vlgothic-*
localectl set-locale LANG=ja_JP.UTF-8
source /etc/locale.conf

STARTWM="/usr/libexec/xrdp/startwm.sh"
if grep -e 'export LANG=ja_JP.UTF-8' $STARTWM; then
	:
else
	sed -i -e 's/#export LANG=$LANG/#export LANG=$LANG\nexport LANG=ja_JP.UTF-8/g' $STARTWM
fi

# firewall config
IPLIST=ip.list
cat > ${IPLIST} @@@ADDR@@@
if [ $(egrep -c "^([0-9]+\.){3}[0-9]+$" ${IPLIST}) -ne 0 ]
then
    for IPADDR in $(egrep "([0-9]+\.){3}[0-9]+$" ${IPLIST})
    do
	    firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${IPADDR}/32' accept"
    done
else
    firewall-cmd --permanent --zone=public --add-port=3389/tcp
fi
firewall-cmd --reload

# XRDP service config
systemctl start xrdp
systemctl enable xrdp

_motd end
