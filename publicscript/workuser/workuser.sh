#!/bin/bash

# @sacloud-name "Create workuser"
# @sacloud-once

# @sacloud-desc SSH作業用ユーザ(workuser)を作成します。
# @sacloud-desc rootユーザのSSHログインを拒否します。

#--------- Create "workuser" ---------#
useradd workuser
usermod -G wheel workuser
echo "password" | passwd --stdin workuser

#--------- Config of pam ---------#
cat <<'EOT' > /etc/pam.d/su
#%PAM-1.0
auth            sufficient      pam_rootok.so
# Uncomment the following line to implicitly trust users in the "wheel" group.
#auth           sufficient      pam_wheel.so trust use_uid
# Uncomment the following line to require a user to be in the "wheel" group.
auth           required        pam_wheel.so use_uid
auth            include         system-auth
account         sufficient      pam_succeed_if.so uid = 0 use_uid quiet
account         include         system-auth
password        include         system-auth
session         include         system-auth
session         optional        pam_xauth.so
auth            include         system-auth
EOT

#--------- Config of sshd_config ---------#
cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config.org
echo "PermitRootLogin no" >> /etc/ssh/sshd_config

service sshd restart
