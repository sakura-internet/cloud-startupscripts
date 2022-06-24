#!/bin/bash

# @sacloud-name "Prometheus & Grafana & Loki for Ubuntu"
# @sacloud-once
# @sacloud-desc-begin
#   さくらのクラウド上で Prometheus , Grafana , Grafana Lokiを自動でセットアップするスクリプトです
#   このスクリプトは Ubuntu でのみ動作します
#   セットアップには10分程度時間がかかります。
#
#   インストールされるソフトウェアのバージョンは以下の通りです
#      * Prometheus (v2.36.2)
#      * sakuracloud_exporter (0.17.1)（任意）
#      * Loki (v2.5.0)
#      * Grafana(v9.0.1-oss)
#   
#   アクセス情報は以下の通りです。
#   Prometheus URL http://サーバーIPアドレス/prometheus
#   ログイン情報 ユーザー名: フォームで設定したユーザー名, フォームで設定したパスワード
#
#   Grafana URL http://サーバーIPアドレス/grafana
#   デフォルトのログイン情報 ユーザー名: admin, パスワード: フォームで設定したパスワード
#
#   ※ 注意
#   Sakura Cloud Exporterを利用するとお客様が利用中のリソース量に応じてメモリ使用量が増加することがあります。
#   PrometheusがSakura Cloud Exporterへの取得に失敗する場合はメモリ量を増やすか、Sakura Cloud Exporterに--no-collectorオプションの設定をお願いいたします。
#
#   独自ドメイン・TLS証明書を設定せずHTTPでご利用いただく場合、ローカルネットワークでご使用ください。
# @sacloud-desc-end
# 
# @sacloud-require-archive distro-ubuntu distro-ver-20.*
# @sacloud-require-archive distro-ubuntu distro-ver-22.*
# @sacloud-checkbox	SAKURACLOUDEXPORTER "Sakura Cloud Exporterを利用する"
# @sacloud-apikey permission=create AK "Sakura Cloud Exporterが利用するAPIキー (Sakura Cloud Exporterを利用する場合は必須)"
# @sacloud-password required GADMINPASS "GrafanaのAdminアカウントのパスワード"
# @sacloud-text required PADMINUSER "Prometheus UIのBasic認証に利用するユーザー名"
# @sacloud-password required PADMINPASS "Prometheus UIのBasic認証に利用するパスワード"


function _motd() {
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

set -eux
trap "_motd fail" ERR

BASEDIR="/usr/local/src"
GRAFANA_ADMIN_PASS=@@@GADMINPASS@@@
USE_SAKURA_CLOUD_EXPORTER=@@@SAKURACLOUDEXPORTER@@@
PROMETHEUS_USER=@@@PADMINUSER@@@
PROMETHEUS_PASS=@@@PADMINPASS@@@

function systemd_service_start() {
	local SERVICE_NAME="$1"
	systemctl daemon-reload
	systemctl enable "$SERVICE_NAME"
	systemctl start "$SERVICE_NAME"
}

function setup_dependencies() {
	echo "[*] Update & Upgrade ..."
	apt-get update -y 
	apt-get upgrade -y
	echo "[*] Installing cUrl ..."
	apt-get install -y curl --fix-missing

	echo "[*] Install unzip ..."
	apt-get install -y zip unzip --fix-missing

	echo "[*] Install Grafana Depends ..."

	apt-get install -y apt-transport-https --fix-missing
	apt-get install -y software-properties-common wget --fix-missing

	echo "[*] Install Apache2 Util"
	apt-get install -y apache2-utils --fix-missing
}

function setup_prometheus() {
	# set local variable for prometheus
	local VERSION="2.36.2"
	local FILEBASE="prometheus-$VERSION.linux-amd64"
	local TARFILE="$FILEBASE.tar.gz"
	local DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/v$VERSION/$TARFILE"

	echo "[*] Download & UnCompress Prometheus ..."
	wget "$DOWNLOAD_URL"
	tar zxvf "$TARFILE"
	rm -rf "$TARFILE"

	echo "[*] Installing Prometheus Service ..."
	useradd -s /sbin/nologin -M prometheus
	chown -R prometheus:prometheus "$BASEDIR/$FILEBASE/"
	cat <<- __EOT__ >> /usr/lib/systemd/system/prometheus.service
	[Unit]
	Description=Prometheus - Monitoring system 
	After=network-online.target

	[Service]
	Type=simple
	User=prometheus
	ExecStart=$BASEDIR/$FILEBASE/prometheus --config.file=$BASEDIR/$FILEBASE/prometheus.yml --storage.tsdb.path=$BASEDIR/$FILEBASE/data/ --web.external-url=http://localhost:9090/prometheus/ --web.route-prefix=/
	Restart=none

	[Install]
	WantedBy=multi-user.target
	__EOT__
	if [[ -n $USE_SAKURA_CLOUD_EXPORTER ]]; then
		cat <<- __EOT__ >> $BASEDIR/$FILEBASE/prometheus.yml
		  - job_name: "sakura_cloud_exporter"
		    scrape_timeout: 1m
		    scrape_interval: 1m
		    static_configs:
		       - targets: ["localhost:9542"]
		__EOT__
	else
		echo "[*] Prometheus Sakura Cloud Exporter Skipped ..."
	fi
	echo "[*] Enable & Start Prometheus Service ..."
	systemd_service_start "prometheus.service"
}


function setup_sakura_cloud_exporter() {
	if [[ -n $USE_SAKURA_CLOUD_EXPORTER ]]; then
		local VERSION="0.17.1"

		echo "[*] Download & UnCompress SakuraCloud Exporter ..."
		wget "https://github.com/sacloud/sakuracloud_exporter/releases/download/$VERSION/sakuracloud_exporter_linux-amd64.zip"
		unzip sakuracloud_exporter_linux-amd64.zip -d ./sakuracloud_exporter

		echo "[*] Installing SakuraCloud Exporter Service ..."
		useradd -s /sbin/nologin -M sakuracloud_exporter

		chown -R sakuracloud_exporter:sakuracloud_exporter "$BASEDIR/sakuracloud_exporter/"
		cat <<- __EOT__ >> /usr/lib/systemd/system/sakuracloud_exporter.service
		[Unit]
		Description=Sakura Cloud Exporter
		Wants=network-online.target
		After=network-online.target
		After=prometheus.service

		[Service]
		User=sakuracloud_exporter
		EnvironmentFile=$BASEDIR/sakuracloud_exporter/sysconfig
		ExecStart=$BASEDIR/sakuracloud_exporter/sakuracloud_exporter
		Restart=none

		[Install]
		WantedBy=multi-user.target
		__EOT__

		sh -c "echo SAKURACLOUD_ACCESS_TOKEN=\"$SACLOUD_APIKEY_ACCESS_TOKEN\" >> $BASEDIR/sakuracloud_exporter/sysconfig"
		sh -c "echo SAKURACLOUD_ACCESS_TOKEN_SECRET=\"$SACLOUD_APIKEY_ACCESS_TOKEN_SECRET\">> $BASEDIR/sakuracloud_exporter/sysconfig"

		echo "[*] Enable & Start SakuraCloud Exporter Service ..."
		systemd_service_start "sakuracloud_exporter.service"
	else
		echo "[!] SakuraCloud Exporter Install Skipped ..."
	fi
}


function setup_grafana() {
	echo "[*] Installing Grafana ..."
	wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -

	echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list
	apt-get update
	apt-get install -y grafana

	echo "[*] Enable & Start Grafana Service ..."
	systemd_service_start "grafana-server"
	sleep 10s
	grafana-cli admin reset-admin-password "$GRAFANA_ADMIN_PASS"
	sleep 10s
	echo "[*] Add Prometheus for Grafana ..."
	curl "http://admin:$GRAFANA_ADMIN_PASS@localhost:3000/api/datasources" -X POST -H 'Content-Type: application/json;charset=UTF-8' -d '{"name":"Prometheus","type":"prometheus","url":"http://localhost:9090", "access":"proxy", "basicAuth":false, "isDefault":true}'
}

function setup_loki() {
	echo "[*] Download & UnCompress Loki ..."
	curl -O -L "https://github.com/grafana/loki/releases/download/v2.5.0/loki-linux-amd64.zip"
	unzip "loki-linux-amd64.zip" -d ./loki

	echo "[*] Configure Loki ..."
	pushd ./loki
	chmod a+x "loki-linux-amd64"
	wget "https://raw.githubusercontent.com/grafana/loki/master/cmd/loki/loki-local-config.yaml"
	popd

	echo "[*] Installing Loki Service ..."
	useradd -s /sbin/nologin -M loki
	chown -R loki:loki "$BASEDIR/loki/"
	
	cat <<- __EOT__ >> /usr/lib/systemd/system/loki.service
	[Unit]
	Description=Loki
	Wants=network-online.target
	After=network-online.target

	[Service]
	User=loki
	ExecStart=$BASEDIR/loki/loki-linux-amd64 --config.file $BASEDIR/loki/loki-local-config.yaml
	Restart=none

	[Install]
	WantedBy=multi-user.target
	__EOT__


	echo "[*] Enable & Start Loki Service ..."
	systemd_service_start "loki.service"

	echo "[*] Add Loki for Grafana ..."
	curl "http://admin:$GRAFANA_ADMIN_PASS@localhost:3000/api/datasources" -X POST -H 'Content-Type: application/json;charset=UTF-8' -d '{"name":"Loki","type":"loki","url":"http://localhost:3100", "access":"proxy", "basicAuth":false, "isDefault":false}'

}

function setup_nginx() {
	echo "[*] Install Nginx ..."
	apt-get install -y nginx

	echo "[*] Setup ufw ..."
	ufw allow "Nginx HTTP"
	ufw allow "OpenSSH"
	ufw allow 3100/tcp
	ufw reload

	echo "[*] enable ufw ..."
	ufw enable
	mkdir /etc/nginx/prometheus/
	echo $PROMETHEUS_PASS | sudo htpasswd -c -i -B -C 15 /etc/nginx/prometheus/.htpasswd $PROMETHEUS_USER

	cat <<- __EOT__ > /etc/nginx/sites-available/default
	server {
	    listen 80 default_server;
	    listen [::]:80 default_server;

	    root /var/www/html;

	    index index.html index.htm index.nginx-debian.html;

	    server_name _;

	    location / {
	        try_files \$uri \$uri/ =404;
	    }
	    location /grafana/ {
	        proxy_pass                              http://localhost:3000/;
	        proxy_redirect                          off;
	        proxy_set_header Host                   \$host;
	        proxy_set_header X-Real-IP              \$remote_addr;
	        proxy_set_header X-Forwarded-Host       \$host;
	        proxy_set_header X-Forwarded-Server     \$host;
	        proxy_set_header X-Forwarded-Proto      \$scheme;
	        proxy_set_header X-Forwarded-For        \$proxy_add_x_forwarded_for;
	    }
	    location /prometheus/ {
	        proxy_pass                              http://localhost:9090/;
	        proxy_redirect                          off;
	        proxy_set_header X-Real-IP              \$remote_addr;
	        proxy_set_header X-Forwarded-Host       \$host;
	        proxy_set_header X-Forwarded-Server     \$host;
	        proxy_set_header X-Forwarded-Proto      \$scheme;
	        proxy_set_header X-Forwarded-For        \$proxy_add_x_forwarded_for;
			auth_basic                              "Prometheus Control Panel is Restricted";                 
        	auth_basic_user_file                    /etc/nginx/prometheus/.htpasswd;
	    }
	}
	__EOT__
	sed -i s/\;root_url\ =\ %\(protocol\)s:\\/\\/%\(domain\)s:%\(http_port\)s\\//root_url\ =\ %\(protocol\)s:\\/\\/%\(domain\)s:%\(http_port\)s\\/grafana\\//g  "/etc/grafana/grafana.ini"
	systemctl restart nginx
	systemctl restart grafana-server
}

function main() {
	pushd $BASEDIR
	setup_dependencies
	setup_prometheus
	setup_sakura_cloud_exporter
	setup_grafana
	setup_loki
	setup_nginx
	popd
}

_motd start
main
_motd end