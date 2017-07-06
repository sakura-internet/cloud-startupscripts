#!/bin/bash

# @sacloud-once

# @sacloud-desc apt-get update/upgradeを実行します。完了後自動再起動します。
# @sacloud-desc （このスクリプトは、DebianもしくはUbuntuでのみ動作します）
# @sacloud-require-archive distro-debian
# @sacloud-require-archive distro-ubuntu

export DEBIAN_FRONTEND=noninteractive

apt-get -y update || exit 1
apt-get -y upgrade || exit 1
sh -c 'sleep 10; reboot' &
exit 0