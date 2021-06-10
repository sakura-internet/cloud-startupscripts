#!/bin/bash
#
# @sacloud-once
# @sacloud-name "Docker Engine for Ubuntu"
# @sacloud-desc Docker Engine の最新安定版をインストールします。
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

# Naviage to root directory.
cd /root

# Reference: https://docs.docker.com/engine/install/ubuntu/
# Uninstall old packages and install required tools.
apt-get remove docker docker-engine docker.io containerd runc || true
apt-get update && apt-get upgrade -y
apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

# Add Docker's offical GPG key.
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine.
apt-get update
apt-get install -y docker-ce-cli containerd.io
# To avoid failed to start 'apt-get install -y docker-ce' only once.
# Show the log below when runs 'apt-get install -y docker-ce' only once.
# -- Logs begin at Wed 2021-05-26 13:21:37 JST, end at Wed 2021-05-26 13:44:04 JST. --
# May 26 13:26:51 ubuntu systemd[1]: Starting Docker Application Container Engine...
# May 26 13:26:52 ubuntu dockerd[35186]: time="2021-05-26T13:26:52.030098275+09:00" level=info msg="Starting up"
# May 26 13:26:52 ubuntu dockerd[35186]: failed to load listeners: no sockets found via socket activation: make sure the service was started by systemd
# May 26 13:26:52 ubuntu systemd[1]: docker.service: Main process exited, code=exited, status=1/FAILURE
# May 26 13:26:52 ubuntu systemd[1]: docker.service: Failed with result 'exit-code'.
# May 26 13:26:52 ubuntu systemd[1]: Failed to start Docker Application Container Engine.
# May 26 13:26:54 ubuntu systemd[1]: docker.service: Scheduled restart job, restart counter is at 1.
# May 26 13:26:54 ubuntu systemd[1]: Stopped Docker Application Container Engine.
# May 26 13:26:54 ubuntu systemd[1]: Starting Docker Application Container Engine...
apt-get install -y docker-ce || apt-get install -y docker-ce

# Complete!
_motd end
