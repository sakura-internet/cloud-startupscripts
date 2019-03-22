#!/bin/bash

# @sacloud-name "SHIRASAGI"
# @sacloud-once

# @sacloud-desc-begin
#   シラサギをセットアップするスクリプトです。
#   オプションの「ドメイン名」を設定すると、
#   ブラウザで "http://example.jp/" にアクセスするとシラサギが表示されるようにシラサギがインストールされます。
#   example.jpの部分は、ご利用のドメインに応じて適時変更してください。
#
#   サーバ作成後、Webブラウザでシラサギの管理画面にアクセスしてください。
#   http://IPアドレス/.mypage
#   初期ID/パスワードは下記URLを参照してください。
#   http://www.ss-proj.org/download/demo.html
#
#   ※ このスクリプトは CentOS 7.X でのみ動作します。
#   ※ 推奨環境：ディスク 40GB
#   ※ セットアップには15分程度時間がかかります。
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-tag @require-core>=2 @require-memory-gib>=3
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

#---------Download SHIRASAGI Install Script---------#
# シラサギのインストーラを入手します。
curl https://raw.githubusercontent.com/shirasagi/shirasagi/master/bin/install.sh > @@@.ID@@@_install.sh

#---------Change nginx Repository---------#
# nginxを、epelでなくnginx.orgからインストールするように変更します。
sed -i 's/sudo yum -y --enablerepo=nginx install nginx/sudo yum -y --disablerepo=epel --enablerepo=nginx install nginx/g' @@@.ID@@@_install.sh

#---------Exec SHIRASAGI Install Script---------#
# シラサギのインストーラを実行します。
bash @@@.ID@@@_install.sh ${SS__HOST}

#---------END OF SHIRASAGI---------#

exit 0
