#!/bin/bash

# @sacloud-name ""
# @sacloud-once
#
# @sacloud-require-archive distro-centos distro-ver-7.*
#
# @sacloud-desc-begin
#   Rancher v2.xをインストールします。
#   サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
#   https://サーバのIPアドレス/
#   (ユーザー名: admin, パスワード: 入力したRancher管理ユーザーのパスワード)
#   ※ セットアップには5分程度時間がかかります。
#   （このスクリプトは、CentOS7.Xでのみ動作します）
# @sacloud-desc-end
#
# Rancherの管理ユーザーの入力フォームの設定
# @sacloud-password required shellarg maxlen=60 password "Rancher 管理ユーザーのパスワード"
# @sacloud-select-begin required default=default ZONE "操作対象ゾーンを選択してください。(defaultはサーバを作成したゾーンになります)
#  default "default"
#  is1a "is1a"
#  is1b "is1b"
#  tk1a "tk1a"
# @sacloud-select-end
# @sacloud-apikey required permission=create AK "APIキー"

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

_motd start
trap '_motd fail' ERR

# コントロールパネルでの入力値
RANCHER_PASSWORD=@@@password@@@
ZONE=@@@ZONE@@@

# Rancherノードテンプレートのデフォルトパラメーター
DEFAULT_CORE=2
DEFAULT_MEMORY=4
DEFAULT_DISK_SIZE=40
DEFAULT_OS_TYPE=rancheros

# 必要なミドルウェアを全てインストール
yum makecache fast || _motd fail
yum -y install curl docker jq || _motd fail
systemctl enable docker.service || _motd fail
systemctl start docker.service || _motd fail

# ゾーンの設定
if [ "${ZONE}" = "default" ]; then
  ZONE=$(jq -r ".Zone.Name" /root/.sacloud-api/server.json)
fi


# ファイアウォールに対し http/https プロトコルでのアクセスを許可する
firewall-cmd --permanent --add-service=http || _motd fail
firewall-cmd --permanent --add-service=https || _motd fail
firewall-cmd --reload

# 必要な情報を集める
IP=`ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1`

# Rancherサーバ起動
docker run -d --restart=unless-stopped \
              -p 80:80 \
              -p 443:443 \
              -v /host/rancher:/var/lib/rancher \
              --name rancher-server \
              rancher/rancher

echo "Booting Rancher Server..."
while ! curl -k -s https://localhost/ping; do sleep 3; done
echo ""
echo "Done."

# エラー回避のため数秒待つ
sleep 5

# パスワード変更のためデフォルトユーザー名/パスワードでログイン
LOGINRESPONSE=`curl -s 'https://127.0.0.1/v3-public/localProviders/local?action=login' -H 'content-type: application/json' --data-binary '{"username":"admin","password":"admin"}' --insecure`
LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`

# パスワード変更
curl -s 'https://127.0.0.1/v3/users?action=changepassword' -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"currentPassword":"admin","newPassword":"'${RANCHER_PASSWORD}'"}' --insecure

# APIキーの取得
APIRESPONSE=`curl -s 'https://127.0.0.1/v3/token' -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"type":"token","description":"automation"}' --insecure`
# Extract and store token
APITOKEN=`echo $APIRESPONSE | jq -r .token`

# RancherサーバのURLを指定
RANCHER_SERVER="https://${IP}"
curl -s 'https://127.0.0.1/v3/settings/server-url' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" -X PUT --data-binary '{"name":"server-url","value":"'${RANCHER_SERVER}'"}' --insecure

# ノードドライバーの登録
docker exec rancher-server kubectl apply -f https://sacloud.github.io/ui-driver-sakuracloud/rancher-custom-node-driver-sakuracloud.yaml || _motd fail

# ノードドライバのダウンロード完了まで数秒待つ
sleep 5

# ノードテンプレートの登録
ADMIN_USER_NAME=`docker exec rancher-server kubectl get users.management.cattle.io -o "custom-columns=NAME:.metadata.name" --no-headers`

cat << EOS > nodeTemplate.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${ADMIN_USER_NAME}
---

apiVersion: management.cattle.io/v3
kind: NodeTemplate
metadata:
  annotations:
    field.cattle.io/creatorId: ${ADMIN_USER_NAME}
  clusterName: ""
  labels:
    cattle.io/creator: norman
  name: nt-rlzzj
  namespace: ${ADMIN_USER_NAME}
sakuracloudConfig:
  accessToken: ${SACLOUD_APIKEY_ACCESS_TOKEN}
  accessTokenSecret: ${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}
  core: "${DEFAULT_CORE}"
  diskConnection: virtio
  diskPlan: ssd
  diskSize: "${DEFAULT_DISK_SIZE}"
  enablePasswordAuth: false
  enginePort: "2376"
  interfaceDriver: virtio
  memory: "${DEFAULT_MEMORY}"
  osType: ${DEFAULT_OS_TYPE}
  packetFilter: ""
  sshKey: ""
  zone: ${ZONE}
spec:
  displayName: sakura-default-template
  driver: sakuracloud
  engineInstallURL: https://releases.rancher.com/install-docker/17.03.sh
  useInternalIpAddress: true
EOS

docker cp nodeTemplate.yaml rancher-server:/ || _motd fail
docker exec rancher-server kubectl apply -f /nodeTemplate.yaml || _motd fail

# 完了メッセージの表示
echo "Rancher server is ready."

echo "========================================================================="
echo "Rancher server URL: ${RANCHER_SERVER}"
echo "========================================================================="

_motd end

