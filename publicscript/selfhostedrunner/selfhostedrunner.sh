#!/bin/bash
# @sacloud-once
# @sacloud-name "SelfHostedRunner"
# @sacloud-desc SelfHostedRunnerをセットアップします。
# @sacloud-text required URL "登録先のリポジトリ、またはオーガニゼーション"
# @sacloud-password required TOKEN "トークン"
# @sacloud-text NAME "Runnerの名前(省略可、全角不可)"
# @sacloud-require-archive distro-ubuntu distro-ver-18.*
# @sacloud-require-archive distro-ubuntu distro-ver-20.*

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
cd /root
# Prevent to fail apt command with timeout
shopt -s expand_aliases
alias apt-get="apt-get -o 'Acquire::Retries=3' -o 'Acquire::https::Timeout=60' -o 'Acquire::http::Timeout=60' -o 'Acquire::ftp::Timeout=60'"

# Update packages
apt-get update && apt-get upgrade -y

# Reference: https://docs.docker.com/engine/install/ubuntu/
# Uninstall old packages and install required tools.
apt-get remove docker docker-engine docker.io containerd runc || true
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
# Install will fail if you run 'apt-get install -y docker-ce' only once.
# This is the log when 'apt-get install -y docker-ce' be runned.
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

# Reference: https://github.com/actions/runner/releases/tag/v2.278.0
# Create a folder
mkdir /opt/actions-runner && cd /opt/actions-runner
# Download runner package
curl -O -L https://github.com/actions/runner/releases/download/v2.278.0/actions-runner-linux-x64-2.278.0.tar.gz
# Extract the installer
tar xzf ./actions-runner-linux-x64-2.278.0.tar.gz

# Create runner user
useradd runner -m
usermod -aG docker runner
echo "runner ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/runner

# Use UUID for runner name if it is empty.
NAME="@@@NAME@@@"
if [ -z "${NAME}" ]; then
    NAME=$(uuidgen)
fi

# Install runner
chown runner:runner . -R
sudo -u runner ./config.sh --url @@@URL@@@ --token @@@TOKEN@@@ --unattended --replace --name "$NAME"
./svc.sh install runner
./svc.sh start

# Complete!
_motd end
