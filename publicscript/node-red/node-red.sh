#!/bin/sh
# @sacloud-name "Node-RED"
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
# @sacloud-text shellarg minlen=5 maxlen=20 ex=username nodered_id "Node-REDのログインID（５文字以上）"
UI_NODERED_ID=@@@nodered_id@@@
# @sacloud-password shellarg minlen=8 maxlen=20 ex=password nodered_password "Node-REDのログインパスワード（８文字以上）"
UI_NODERED_PASSWORD=@@@nodered_password@@@
 
export HOME=/root/ && export PM2_HOME="/root/.pm2"
 
# yum update
echo "# yum update"
yum -y update || exit 1
 
### nano
echo "# ADD nano"
sudo yum install -y nano || exit 1
 
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
 
### 一旦ストップ
echo "# nodered stop"
pm2 stop node-red || exit 1
 
# ポート公開
echo "# firewalld setting"
firewall-cmd --add-port=$UI_PORT/tcp --permanent || exit 1
### ADD MQTT
firewall-cmd --add-port=1883/tcp --permanent || exit 1
firewall-cmd --reload || exit 1
 
### ノード追加
echo "# add nodered node"
cd /root/.sacloud-api/notes/root || exit 1
sudo npm install node-red-dashboard node-red-contrib-os node-red-contrib-mqtt-broker --unsafe-perm || exit 1
 
# パスワード抽出
echo "# nodered password crypt make"
npm install bcryptjs || exit 1
UI_NODERED_PASSWORD_CRYPT=`node -e "console.log(require('bcryptjs').hashSync(process.argv[1], 8));" ${UI_NODERED_PASSWORD}`  || exit 1
 
# パスワード変更　事前置き換え
echo "# nodered password template push"
sed -i -e "s/\/\/adminAuth:/adminAuth:{\n\
        type: \"credentials\",\n\
        users: [{\n\
            username: \"admin\",\n\
            password: \"SACLOUD_NODERED_PASSWORD\",\n\
            permissions: \"*\"\n\
        }]\n\
    },\n\
    \/\/adminAuth:/" /root/.sacloud-api/notes/root/settings.js || exit 1
 
# パスワード変更
echo "# nodered password crypt change"
sed -i -e "s*SACLOUD_NODERED_PASSWORD*$UI_NODERED_PASSWORD_CRYPT*" /root/.sacloud-api/notes/root/settings.js || exit 1
 
### restart
echo "# nodered restart"
pm2 start node-red || exit 1
 
exit 0
