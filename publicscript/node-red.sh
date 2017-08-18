#!/bin/sh
# @sacloud-once
# @sacloud-desc NVM/Node.js/Node-REDのインストールを実行します。
# @sacloud-desc このスクリプトは、CentOS 7.xでのみ動作します。
# @sacloud-desc 完了後「http://<IPアドレス>:1880/」にWebブラウザからアクセスできます。
# @sacloud-desc UIポート番号を指定した場合は、指定したポート番号でアクセスできます。
# @sacloud-desc Node-Redのログを確認するには「 pm2 logs node-red」コマンドを実行します。
# @sacloud-require-archive distro-centos distro-ver-7.*

# @sacloud-text shellarg maxlen=5 ex=1880 integer min=80 max=65535 ui_port "Node-REDのWeb UIポート番号"
UI_PORT=@@@ui_port@@@
${UI_PORT:=1880}
export HOME=/root/ && export PM2_HOME="/root/.pm2"

# Node.jsとNode-Redのセットアップ
curl -sL https://rpm.nodesource.com/setup_8.x | bash -
yum install -y nodejs || exit 1
npm install -g --unsafe-perm node-red || exit 1

# Node-Red自動起動設定
npm install -g pm2
pm2 start /usr/bin/node-red -- -v -u root -p $UI_PORT
pm2 save
pm2 startup systemd -u root

# ポート公開
firewall-cmd --add-port=$UI_PORT/tcp --permanent
firewall-cmd --reload

exit 0
