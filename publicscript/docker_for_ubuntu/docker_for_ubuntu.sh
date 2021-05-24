#!/bin/bash
#
# @sacloud-once
# @sacloud-name "Docker Engine CE for Ubuntu"
# @sacloud-desc Docker Engine Community Edition の最新安定版をインストールします。
#
# @sacloud-require-archive distro-ubuntu

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

# Naviage to root direcotry.
echo "* cd root dir"
cd /root

# Install Docker Engine.
# Reference: https://docs.docker.com/engine/install/ubuntu/
echo "* Uninstall old packages and install required tools"
apt-get remove docker docker-engine docker.io containerd runc
apt-get update
apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo "* Add Docker's offical GPG key"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "* Install Docker Engine"
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io

echo "* Start Docker service and setup to start it automatically at boot"
systemctl start docker
systemctl enable docker

# 設定完了を表示
echo "* Complete!"

_motd end



