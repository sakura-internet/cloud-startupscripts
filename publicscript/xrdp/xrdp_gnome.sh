#!/bin/bash

# regist epel
yum -y install epel-release || exit 1
yum -y update || exit 1
# install XRDP
yum -y --enablerepo=epel install xrdp || exit 1
yum -y --enablerepo=epel install tigervnc-server || exit 1
# install GNOME
yum -y groups install "GNOME Desktop" || exit 1
systemctl set-default graphical.target || exit 1

# XRDP color change: 32bit -> 64bit
sed -i -e 's/max_bpp=32/max_bpp=24/g' /etc/xrdp/xrdp.ini || exit 1

# install and config japanese environment
yum -y install ibus-kkc vlgothic-* || exit 1
localectl set-locale LANG=ja_JP.UTF-8 || exit 1
source /etc/locale.conf || exit 1

STARTWM="/usr/libexec/xrdp/startwm.sh"
if grep -e 'export LANG=ja_JP.UTF-8' $STARTWM; then
  :
else
  sed -i -e 's/#export LANG=$LANG/#export LANG=$LANG\nexport LANG=ja_JP.UTF-8/g' $STARTWM || exit 1
fi

# firewall config
firewall-cmd --permanent --zone=public --add-port=3389/tcp || exit 1
firewall-cmd --reload || exit 1

# XRDP service config
systemctl start xrdp.service || exit 1
systemctl enable xrdp.service || exit 1

exit 0
