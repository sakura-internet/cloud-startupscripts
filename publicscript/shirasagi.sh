#!/bin/bash

# @sacloud-once

# @sacloud-desc-begin
#   Ruby、Ruby on Rails、MongoDBで動作する中・大規模サイト向けCMSであるシラサギをセットアップするスクリプトです。
#   オプションの「ドメイン名」を設定すると、
#   ブラウザで "http://example.jp/" にアクセスするとシラサギが表示されるようにシラサギがインストールされます。
#   example.jpの部分は、ご利用のドメインに応じて適時変更してください。
#   
#   サーバ作成後、Webブラウザでシラサギの管理画面にアクセスしてください。
#   http://IPアドレス:3000/.mypage
#   初期ID/パスワードは下記URLを参照してください。
#   http://www.ss-proj.org/download/demo.html
#
#   ※ このスクリプトは CentOS 7.X でのみ動作します。
#   ※ 推奨環境：CPU 2コア / メモリ 3GB / ディスク 40GB
#   ※ セットアップには10分程度時間がかかります。
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-text SSHOST "ドメイン名"

#---------SET SS__HOST---------#
# ユーザがドメイン名を入力していればそれを、
# 入力していなければIPアドレスをSS__HOSTに設定します。
SS_HOST=@@@SSHOST@@@
IPADDR=$(awk -F= '/^IPADDR=/{print $2}' /etc/sysconfig/network-scripts/ifcfg-eth0)

if [[ ${SS_HOST} != "" ]]
then
  SS__HOST=${SS_HOST}
else
  SS__HOST=${IPADDR}
fi

#---------START OF SHIRASAGI---------#
# シラサギのインストーラを実行します。
curl https://raw.githubusercontent.com/shirasagi/shirasagi/master/bin/install.sh | bash -s ${SS__HOST}
#---------END OF SHIRASAGI---------#

#---------START OF firewalld---------#
# シラサギの管理画面は3000番ポートを使用するため、
# サーバに対して3000番ポートでアクセスできるようにします。
firewall-cmd --permanent --add-port=3000/tcp
firewall-cmd --reload
#---------END OF firewalld---------#

exit 0