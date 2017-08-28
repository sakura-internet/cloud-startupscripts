#!/bin/sh
# @sacloud-once
# @sacloud-desc NVM/Node.js/Node-REDのインストールを実行します。
# @sacloud-desc このスクリプトは、CentOS 7.xでのみ動作します。
# @sacloud-desc nodesourceリポジトリを追加登録します。
# @sacloud-desc 完了後「http://<IPアドレス>:1880/」にWebブラウザからアクセスできます。
# @sacloud-desc UIポート番号を指定した場合は、指定したポート番号でアクセスできます。
# @sacloud-desc Node-Redのログを確認するには「 pm2 logs node-red」コマンドを実行します。
# @sacloud-require-archive distro-centos distro-ver-7.*

# @sacloud-text shellarg maxlen=5 ex=1880 integer min=80 max=65535 ui_port "Node-REDのWeb UIポート番号"
UI_PORT=@@@ui_port@@@
${UI_PORT:=1880}
export HOME=/root/ && export PM2_HOME="/root/.pm2"

# yum update
echo "# yum update"
yum -y update || exit 1

# リポジトリ登録
echo "# add nodesource"
curl -sL https://rpm.nodesource.com/setup_8.x | bash - || exit 1

# Node.jsとNode-Redのセットアップ
echo "# nodejs / node-red install"
yum install -y nodejs || exit 1
npm install -g --unsafe-perm node-red || exit 1

# Node-Red自動起動設定
echo "# nodered setting"
npm install -g pm2 || exit 1
pm2 start /usr/bin/node-red -- -v -u root -p $UI_PORT || exit 1
pm2 save || exit 1
pm2 startup systemd -u root || exit 1

# ポート公開
echo "# firewalld setting"
firewall-cmd --add-port=$UI_PORT/tcp --permanent || exit 1
firewall-cmd --reload || exit 1

exit 0

