#!/bin/bash

# @sacloud-name "Ruby on Rails"
# @sacloud-once
#
# @sacloud-require-archive distro-centos distro-ver-6.*
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-require-archive distro-centos distro-ver-8.*
#
# @sacloud-desc-begin
# rbenv、Bundler、Ruby on Rails をインストールするスクリプトです。
# このスクリプトは、CentOS 6.X, 7.X, 8.X でのみ動作します。
# このスクリプトは完了までに10分程度時間がかかります。
# スクリプトの進捗状況は /root/.sacloud-api/notes/スタートアップスクリプトID.log をご確認ください。
# @sacloud-desc-end
# @sacloud-text required default="rbenv" shellarg user 'rbenv を利用するユーザー名'
# @sacloud-text required default="2.6.5" shellarg ruby_version 'global で利用する Ruby のバージョン'
# @sacloud-checkbox default="1" shellarg create_gemrc 'gem の install と update 時に --no-document オプションを付与する .gemrc を作成する'

# コントロールパネルの入力値を変数へ代入
user=@@@user@@@
ruby_version=@@@ruby_version@@@
create_gemrc=@@@create_gemrc@@@

if [ $user != "root" ]; then
 home="/home/$user"
else
 home="/root"
fi

# ユーザーの設定
if ! cat /etc/passwd | awk -F : '{ print $1 }' | egrep ^$user$; then
 adduser $user
fi

echo "[1/5] Ruby のインストールに必要なライブラリをインストール中..."
# https://github.com/rbenv/ruby-build/wiki#suggested-build-environment
yum install -y gcc
yum install -y bzip2
yum install -y openssl-devel
yum install -y libyaml-devel
yum install -y libffi-devel
yum install -y readline-devel
yum install -y zlib-devel
yum install -y gdbm-devel
yum install -y ncurses-devel

echo "[1/5] Ruby のインストールに必要なライブラリをインストールしました"

echo "[2/5] rbenv をインストール中..."
git clone https://github.com/sstephenson/rbenv.git      $home/.rbenv
git clone https://github.com/sstephenson/ruby-build.git $home/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> $home/.bash_profile
echo 'eval "$(rbenv init -)"'               >> $home/.bash_profile
chown -R $user:$user $home/.rbenv
echo "[2/5] rbenv をインストールしました"


if [ "$create_gemrc" = "1" ]; then
cat << __EOS__ > $home/.gemrc
install: --no-document
update:  --no-document
__EOS__
 chown $user:$user $home/.gemrc
fi

echo "[3/5] Ruby のインストール中..."
su -l $user -c "rbenv install $ruby_version"
su -l $user -c "rbenv global  $ruby_version"
su -l $user -c "rbenv rehash"
echo "[3/5] Ruby をインストールしました"

echo "[4/5] Bundler のインストール中..."
su -l $user -c "rbenv exec gem i bundler"
echo "[4/5] Bundler をインストールしました"

echo "[5/5] Rails のインストール中..."
su -l $user -c "rbenv exec gem i rails"
echo "[5/5] Rails をインストールしました"

echo "スタートアップスクリプトの処理が完了しました"
