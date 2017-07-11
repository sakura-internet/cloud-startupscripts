#!/bin/bash

# @sacloud-once
#
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-require-archive distro-centos distro-ver-6.*
#
# @sacloud-desc-begin
#    CentOS 7.x or 6.xの初期設定をします
#    * パッケージの最新化
#    * 新規ユーザの作成
#    * suコマンドの制限
#      * suコマンドの実行可能ユーザ・グループを限定する
#      * パスワード入力なしでsudoコマンドを利用可能にする
#    * ssh接続の制限
#      * rootユーザのsshログインを禁止する
#      * 公開鍵認証のみ接続を許可する
#    ※ fail2banによりログインできなくなる場合があります
# @sacloud-desc-end
#
# @sacloud-text required shellarg maxlen=60 user_name "新規追加するユーザ名"
# @sacloud-password required shellarg maxlen=60 user_pass "新規追加するユーザのパスワード"
# @sacloud-textarea required shellarg maxlen=512 public_key "利用する公開鍵"

USER=@@@user_name@@@
PW=@@@user_pass@@@
PUBKEY=@@@public_key@@@
CENTOS_VERSION=@@@centos_version@@@

# disable SELinux temporarily
setenforce 0


# package update
yum -y update


# create user
useradd $USER
echo $PW | passwd --stdin $USER
gpasswd -a $USER wheel


# allow only members of the wheel group to use 'su'
cp /etc/pam.d/su /etc/pam.d/su.bak
## uncomment 'auth required pam_wheel.so use_uid'
tac /etc/pam.d/su > /etc/pam.d/su.tmp
cat << EOS >> /etc/pam.d/su.tmp 2>&1
auth required pam_wheel.so use_uid
EOS
tac /etc/pam.d/su.tmp > /etc/pam.d/su
rm -rf /etc/pam.d/su.tmp

## restrict the use of 'su' command
cp /etc/login.defs /etc/login.defs.bak
cat << EOS >> /etc/login.defs
SU_WHEEL_ONLY yes
EOS

## 'sudo' command without password
cp /etc/sudoers /etc/sudoers.bak
cat << EOS >> /etc/sudoers 2>&1
%wheel ALL=(ALL) NOPASSWD: ALL
EOS


# disallow SSH login and add public_key
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
cat << EOS >> /etc/ssh/sshd_config 2>&1
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
AuthorizedKeysFile .ssh/authorized_keys
EOS


mkdir /home/$USER/.ssh/
chmod go-w /home/$USER/.ssh/
touch /home/$USER/.ssh/authorized_keys
cat << EOS >> /home/$USER/.ssh/authorized_keys 2>&1
$PUBKEY
EOS
chmod 600 /home/$USER/.ssh/authorized_keys
chown -R $USER:$USER /home/$USER/.ssh/


# sshd service restart
CENTOS_VERSION=$(cat /etc/redhat-release | sed -e 's/.*\s\([0-9]\)\..*/\1/')
if [ $CENTOS_VERSION = "7" ]; then
  systemctl restart sshd
elif [ $CENTOS_VERSION = "6" ]; then
  /etc/rc.d/init.d/sshd restart
fi

exit 0