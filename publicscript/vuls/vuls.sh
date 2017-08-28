#!/bin/bash
#
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトはLinuxサーバに存在する脆弱性をスキャンするVulsをセットアップします。
# (このスクリプトは、CentOS7.Xでのみ動作します。)
#
# 脆弱性情報のデーターベースを取得する為、
# セットアップが完了するまでに30分程度のお時間がかかります。
# 
# 下記のコマンドで脆弱性情報が取得できればセットアップは完了しています。
# # su - vuls -c "vuls scan"
#
# @sacloud-desc-end

set -x

# Install requirements
GOVERSION=1.8.3
yum install -y yum-plugin-changelog sqlite git gcc make
curl -O https://storage.googleapis.com/golang/go${GOVERSION}.linux-amd64.tar.gz
tar -C /usr/local/ -xzf go${GOVERSION}.linux-amd64.tar.gz

cat << '_EOF_' > /etc/profile.d/goenv.sh
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
_EOF_

# create vuls user
ID=1868
groupadd -g ${ID} vuls
useradd -g ${ID} -u ${ID} -c "The spell of destruction" vuls
mkdir /var/log/vuls
chown vuls /var/log/vuls
chmod 700 /var/log/vuls

cat << '_EOF_' >> /etc/sudoers

# vuls settings
Defaults:vuls !requiretty
vuls ALL=(ALL) NOPASSWD:/usr/bin/yum --changelog --assumeno update *
Defaults:vuls env_keep="http_proxy https_proxy HTTP_PROXY HTTPS_PROXY"
_EOF_

SETUP=/home/vuls/setup.sh
cat << '_EOF_' > ${SETUP}
# Deploy go-cve-dictionary
set -x
source /etc/profile.d/goenv.sh
mkdir -p $GOPATH/src/github.com/kotakanbe
cd $GOPATH/src/github.com/kotakanbe
git clone https://github.com/kotakanbe/go-cve-dictionary.git
cd go-cve-dictionary
make install
cd ${HOME}
for i in $(seq 2002 $(date +"%Y")); do go-cve-dictionary fetchnvd -years $i; done
for i in $(seq 1998 $(date +"%Y")); do go-cve-dictionary fetchjvn -years $i; done

# Deploy Vuls
mkdir -p $GOPATH/src/github.com/future-architect
cd $GOPATH/src/github.com/future-architect
git clone https://github.com/future-architect/vuls.git
cd vuls
make install

# Config
cd ${HOME}
cat << _EOL_ > config.toml
[servers]

[servers.localhost]
host         = "localhost"
port        = "local"
_EOL_
_EOF_

su - vuls -c "bash ./setup.sh"

echo "$((${RANDOM}%60)) $((${RANDOM}%24)) * * 1,3,5 vuls source /etc/profile.d/goenv.sh && go-cve-dictionary fetchnvd -last2y >/dev/null 2>&1" > /etc/cron.d/vuls
echo "$((${RANDOM}%60)) $((${RANDOM}%24)) * * 2,4,6 vuls source /etc/profile.d/goenv.sh && go-cve-dictionary fetchjvn -last2y >/dev/null 2>&1" >> /etc/cron.d/vuls

# Check config.toml and settings on the server before scanning
su - vuls -c "vuls configtest"

exit 0