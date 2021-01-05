#!/bin/bash

# @sacloud-once
# @sacloud-name "Cockpit for CentOS"
# @sacloud-desc Cockpit の最新安定版をインストールします。
#
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-require-archive distro-centos distro-ver-8.*

set -x

yum clean all && sleep 1
yum install -y cockpit || exit 1

sed 's/9090/0.0.0.0:9090/' /usr/lib/systemd/system/cockpit.socket >/etc/systemd/system/cockpit.socket
systemctl daemon-reload
systemctl enable --now cockpit.socket

FWSTAT=$(systemctl status firewalld.service | awk '/Active/ {print $2}')

if [ "${FWSTAT}" = "inactive" ]; then
    systemctl start firewalld.service
    firewall-cmd --zone=public --add-service=ssh --permanent
    systemctl enable firewalld.service
fi

firewall-cmd --permanent --zone=public --add-service=cockpit

echo "reboot after 10 seconds.";
sh -c 'sleep 10; reboot' &

exit 0