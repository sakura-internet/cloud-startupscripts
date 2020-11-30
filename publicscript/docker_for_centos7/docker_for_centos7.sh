#!/bin/bash
#
# @sacloud-once
# @sacloud-name "Docker Engine CE for CentOS 7"
# @sacloud-desc Docker Engine Community Edition の最新安定版をインストールします。
#
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-tag @simplemode @logo-alphabet-d

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
set -ex
trap '_motd fail' ERR

# set $HOME
echo "* Set HOME"
HOME="/root"
export HOME

# cd ~
echo "* cd home dir"
cd /root

# 関連パッケージとリポジトリのセットアップ
echo "* 関連パッケージとリポジトリのセットアップ"
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager -y --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io

echo "* デーモンの起動と、ブート時自動起動設定"
systemctl start docker
systemctl enable docker

# 設定完了を表示
echo "* 設定完了"

_motd end



