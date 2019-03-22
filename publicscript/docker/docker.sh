#!/bin/bash

# @sacloud-name "Docker"
# @sacloud-once
# @sacloud-require-archive distro-ubuntu
# @sacloud-require-archive distro-debian
# @sacloud-require-archive distro-centos

# @sacloud-desc dockerとdocker-composeをインストールします

export DEBIAN_FRONTEND=noninteractive
PKG_MANAGER=""


function pkg_update() {
    case ${PKG_MANAGER} in
      "apt" ) apt update;;
    esac
}

function pkg_upgrade() {
    case ${PKG_MANAGER} in
      "yum" ) yum update -y;;
      "apt" ) apt upgrade -y;;
    esac
}

function pkg_install() {
    case ${PKG_MANAGER} in
      "yum" ) yum install -y $@;;
      "apt" ) apt install -y $@;;
    esac
}


if which yum; then
  PKG_MANAGER="yum"
fi
if which apt; then
  PKG_MANAGER="apt"
fi

echo ${PKG_MANAGER}

pkg_update
pkg_upgrade
pkg_install curl gnupg
curl -fsSL https://get.docker.com/ | sh
pkg_install docker-compose
systemctl enable docker
reboot
