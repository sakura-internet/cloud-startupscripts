#!/bin/bash

# @sacloud-once
# @sacloud-desc-begin
#   GitLabをインストールします。
#   サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
#   http://サーバのIPアドレス/
#   ※ セットアップには5分程度時間がかかります。
#   （このスクリプトは、CentOS7.Xでのみ動作します）
# @sacloud-desc-end
# @sacloud-password required shellarg maxlen=100 minlen=8 ex="put_password_here" GITLAB_INITIAL_PASSWORD "管理者(rootユーザ)の初期パスワード(8文字以上)"

set -e

export GITLAB_ROOT_PASSWORD=@@@GITLAB_INITIAL_PASSWORD@@@

#*******************************************************************************
# ref: https://about.gitlab.com/installation/#centos-7
#*******************************************************************************

# 1. Install and configure the necessary dependencies
yum install curl policycoreutils openssh-server openssh-clients -y
yum install postfix -y
systemctl enable postfix
systemctl start postfix
firewall-cmd --permanent --add-service=http
firewall-cmd --reload

# 2. Add the GitLab package server and install the package
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | bash
yum install gitlab-ce -y

# 3. Configure and start GitLab
gitlab-ctl reconfigure

exit 0
