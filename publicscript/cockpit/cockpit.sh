#!/bin/bash

# @sacloud-once
# @sacloud-name "Cockpit"
# @sacloud-desc Cockpit の最新安定版をインストールします。
#
# @sacloud-require-archive distro-centos distro-ver-7
# @sacloud-require-archive distro-centos distro-ver-8

set -eux

yum install -y cockpit

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
firewall-cmd --reload
