#!/bin/bash

set -eux

# @sacloud-once
# @sacloud-desc-begin
# Nginx, minio をインストールするスクリプトです。
# (このスクリプトは Ubuntu Server 16.04* でのみ動作します)
# 管理画面を有効にした場合、指定したAccess KeyとSecret Key（さくらのクラウドAPIとは異なります）で管理画面を操作できます。
# サーバ作成後、http://<サーバのIPアドレス>/ にアクセスください。
# Debian系でsystemdにのみに対応しているスクリプトです。
# @sacloud-desc-end
# @sacloud-require-archive distro-ubuntu distro-ver-16.04*
# @sacloud-checkbox default="on" shellarg enablecpanel '管理画面を有効にする'
# @sacloud-text required minlen=5 maxlen=20 ex="accessKey" shellarg accesskey '管理画面用 / API Access Key'
# @sacloud-password required minlen=8 maxlen=100 ex="secretKey" shellarg secretkey '管理画面用 / API Secret Key'
# @sacloud-text required default="us-east-1" shellarg region 'リージョン名'

#===== Sacloud Vars =====#
MINIO_ACCESS_KEY=@@@accesskey@@@
MINIO_SECRET_KEY=@@@secretkey@@@
MINIO_REGION=@@@region@@@
MINIO_CPANEL_ENABLED=@@@enablecpanel@@@
if [ -z $MINIO_CPANEL_ENABLED ]; then
  MINIO_BROWSER="off"
else
  MINIO_BROWSER="on"
fi
#===== Sacloud Vars =====#

#===== Consts =====#
export DEBIAN_FRONTEND=noninteractive
MINIO_RELEASE_URL=https://dl.minio.io/server/minio/release/linux-amd64/minio
MINIO_BIN=/usr/local/bin/minio
MINIO_PORT=9000
MINIO_DATA_DIR=/var/minio
#===== Consts =====#

#===== Common =====#
echo "[*] Set up ufw ..."
ufw allow 22 || exit 1
ufw allow 80 || exit 1
ufw allow 443 || exit 1
ufw enable || exit 1

echo "[*] Updating packages ..."
apt-get update
apt-get upgrade -y

echo "[*] Installing required packages ..."
apt-get install -y nginx wget
#===== Common =====#


#===== Nginx =====#
echo "[*] Stopping Nginx ..."
systemctl stop nginx

echo "[*] Configuring /etc/nginx/conf.d/minio_upstream.conf ..."
cat << __EOT__ > /etc/nginx/conf.d/minio_upstream.conf
upstream minio {
  server 127.0.0.1:${MINIO_PORT};
}
__EOT__

echo "[*] Configuring /etc/nginx/sites-available/default ..."
cat << __EOT__ > /etc/nginx/sites-available/default
server {
	listen 80 default_server;
	listen [::]:80 default_server;

	root /var/www/html;

	server_name _;

	location / {
		include proxy_params;
		proxy_pass http://minio;
	}
}
__EOT__

echo "[*] Enable & Start Nginx ..."
systemctl enable nginx
systemctl start nginx
echo "[+] success"
#===== Nginx =====#


#===== minio =====#
echo "[*] Creating minio user and group ..."
groupadd minio
useradd -g minio -d ${MINIO_DATA_DIR} -c "minio" minio

echo "[*] Creating minio directory ..."
mkdir -p ${MINIO_DATA_DIR}
chown minio ${MINIO_DATA_DIR}

echo "[*] Installing minio ..."
wget -O ${MINIO_BIN} ${MINIO_RELEASE_URL}
chmod +x ${MINIO_BIN}


echo "[*] Configuring /etc/default/minio ..."
cat << __EOT__ > /etc/default/minio
# Remote node configuration.
MINIO_VOLUMES=${MINIO_DATA_DIR}
# Use if you want to run Minio on a custom port.
MINIO_OPTS="--address 127.0.0.1:${MINIO_PORT}"
# Enable browser Access
MINIO_BROWSER=${MINIO_BROWSER}

# Access Key of the server.
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
# Secret key of the server.
MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
__EOT__


echo "[*] Configuring /etc/systemd/system/minio.service ..."
cat << __EOT__ > /etc/systemd/system/minio.service
[Unit]
Description=Minio
Documentation=https://docs.minio.io
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=${MINIO_BIN}

[Service]
WorkingDirectory=${MINIO_DATA_DIR}
User=minio
Group=minio
PermissionsStartOnly=true
EnvironmentFile=-/etc/default/minio
ExecStart=${MINIO_BIN} server \$MINIO_OPTS \$MINIO_VOLUMES
StandardOutput=journal
StandardError=inherit

# Specifies the maximum file descriptor number that can be opened by this process
LimitNOFILE=65536

# Disable timeout logic and wait until process is stopped
TimeoutStopSec=0

# SIGTERM signal is used to stop Minio
KillSignal=SIGTERM

SendSIGKILL=no

SuccessExitStatus=0

Restart=always

[Install]
WantedBy=multi-user.target
__EOT__


echo "[*] Enable & Start minio ..."
systemctl enable minio
systemctl start minio
echo "[+] success"
#===== minio =====#


echo "[+] Install Finished."
