#!/bin/sh
# @sacloud-name "Node-RED"
# @sacloud-once
# @sacloud-desc NVM/Node.js/Node-REDのインストールを実行します。
# @sacloud-desc このスクリプトは、CentOS 7.xでのみ動作します。
# @sacloud-desc nodesourceリポジトリを追加登録します。
# @sacloud-desc 完了後「http://<IPアドレス>:1880/」にWebブラウザからアクセスできます。
# @sacloud-desc UIポート番号を指定した場合は、指定したポート番号でアクセスできます。
# @sacloud-desc ログイン画面を有効にする場合は、ログインIDとパスワードを入力してください。
# @sacloud-desc Node-Redのログを確認するには「 pm2 logs node-red」コマンドを実行します。
# @sacloud-require-archive distro-centos distro-ver-7.*

# @sacloud-text shellarg maxlen=5 ex=1880 integer min=80 max=65535 ui_port "Node-REDのWeb UIポート番号"
UI_PORT=@@@ui_port@@@
${UI_PORT:=1880}
# @sacloud-text shellarg minlen=5 maxlen=20 ex=username nodered_id "Node-REDのログインID（５文字以上）"
UI_NODERED_ID=@@@nodered_id@@@
# @sacloud-password shellarg minlen=8 maxlen=20 ex=password nodered_password "Node-REDのログインパスワード（８文字以上）"
UI_NODERED_PASSWORD=@@@nodered_password@@@

_motd() {
	LOG=$(ls /root/.sacloud-api/notes/*log)
	case $1 in
		start)
			echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
		;;
		fail)
			echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
			exit 1
		;;
		end)
			cp -f /dev/null /etc/motd
		;;
	esac
}

# ready for startup script
_motd start
set -e
trap '_motd fail' ERR

export HOME=/root/ && export PM2_HOME="/root/.pm2"

# yum update
echo "# yum update"
yum -y update

# リポジトリ登録
echo "# add nodesource"
curl -sL https://rpm.nodesource.com/setup_8.x | bash -

# Node.jsとNode-Redのセットアップ
echo "# nodejs / node-red install"
yum install -y nodejs
npm install -g --unsafe-perm node-red

# Node-Red自動起動設定
echo "# nodered setting"
npm install -g pm2
pm2 start /usr/bin/node-red -- -u root -p $UI_PORT
pm2 save
pm2 startup systemd -u root

# ポート公開
echo "# firewalld setting"
firewall-cmd --add-port=$UI_PORT/tcp --permanent
firewall-cmd --reload

if [ -n "${UI_NODERED_ID}" ] && [ -n "${UI_NODERED_PASSWORD}" ]
then

	# パスワード抽出
	echo "# nodered password crypt make"
	npm install bcryptjs
	UI_NODERED_PASSWORD_CRYPT=`node -e "console.log(require('bcryptjs').hashSync(process.argv[1], 8));" ${UI_NODERED_PASSWORD}`

	# パスワード変更　事前置き換え
	echo "# nodered password template push"
	sed -i -e "s/\/\/adminAuth:/adminAuth:{\n\
        type: \"credentials\",\n\
        users: [{\n\
            username: \"SACLOUD_NODERED_ID\",\n\
            password: \"SACLOUD_NODERED_PASSWORD\",\n\
            permissions: \"*\"\n\
        }]\n\
    },\n\
    \/\/adminAuth:/" /root/.sacloud-api/notes/root/settings.js

	# ログインIDの変更
	echo "# nodered login id change"
	sed -i -e "s*SACLOUD_NODERED_ID*${UI_NODERED_ID}*" /root/.sacloud-api/notes/root/settings.js

	# パスワード変更
	echo "# nodered password crypt change"
	sed -i -e "s*SACLOUD_NODERED_PASSWORD*${UI_NODERED_PASSWORD_CRYPT}*" /root/.sacloud-api/notes/root/settings.js

	### restart
	echo "# node-red restart"
	pm2 restart node-red
fi

_motd end

exit 0

