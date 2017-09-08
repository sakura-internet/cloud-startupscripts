#!/bin/bash

# @sacloud-name Kibana
# @sacloud-once
# @sacloud-desc-begin
# Fluentd, Elasticsearch, Kibanaをインストールするスクリプトです。
# fluent-plugin-dstatを有効にすると、dstatをインストールし、
# dstatの実行結果が保存され、可視化することができます。
# CentOS 7.x系のみに対応しているスクリプトです。
# サーバ作成後、http://<サーバのIPアドレス>/ にアクセスください。
# 登録したBasic認証でログインすると、Kibanaのコントロールパネルが表示されます。
# @sacloud-desc-end
# @sacloud-text required ex="user" shellarg basicuser 'Basic認証のユーザ名'
# @sacloud-password required ex="" shellarg basicpass 'Basic認証のパスワード'
# @sacloud-checkbox default="" shellarg enabledstat 'fluent-plugin-dstatを有効にする'

#===== Startup Script Motd Monitor =====#
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
set -ex
trap '_motd fail' ERR

#===== Sacloud Vars =====#
BASIC_USER=@@@basicuser@@@
if [ -z $BASIC_USER ]; then
    echo "BASIC_USER is not defined."
    _motd fail
fi

BASIC_PASS=@@@basicpass@@@
if [ -z $BASIC_PASS ]; then
    echo "BASIC_PASS is not defined."
    _motd fail
fi

FLUENT_PLUGIN_DSTAT_ENABLED=@@@enabledstat@@@
if [ -z $FLUENT_PLUGIN_DSTAT_ENABLED ]; then
    FLUENT_PLUGIN_DSTAT_ENABLED="0"
fi
#===== Sacloud Vars =====#

#===== Common =====#
yum update -y
echo "[*] Installing fluentd required plugins..."
yum install -y gcc wget curl libcurl-devel
echo "[*] Installing elasticsearch required plugins..."
yum install -y java-1.8.0-openjdk
echo "[*] Installing httpd-tools..."
yum install -y httpd-tools
yum install -y --enablerepo=epel nginx
echo "[*] Opening Nginx(80/tcp)..."
firewall-cmd --add-service=http --zone=public --permanent
if [ $FLUENT_PLUGIN_DSTAT_ENABLED = "1" ]; then
    echo "[*] Installing dstat..."
    yum install -y dstat
fi
echo "[*] Opening Fluentd(24224/tcp)..."
firewall-cmd --add-port=24224/tcp --zone=public --permanent
firewall-cmd --reload
#===== Common =====#

#===== Fluentd =====#
echo "[*] Installing td-agent..."
curl -L http://toolbelt.treasuredata.com/sh/install-redhat-td-agent2.sh | sh
echo "[*] Installing td-agent-gem (fluent-plugin-elasticsearch)"
td-agent-gem install fluent-plugin-elasticsearch

if [ $FLUENT_PLUGIN_DSTAT_ENABLED = "1" ]; then
    echo "[*] Installing td-agent-gem (fluent-plugin-dstat)"
    td-agent-gem install fluent-plugin-dstat

    echo "[*] Configuring /etc/td-agent/td-agent.conf..."
    cat << __EOT__ >> /etc/td-agent/td-agent.conf

<source>
    type dstat
    tag dstat.__HOSTNAME__
    option -cmdgn
    delay 3
</source>

<match dstat.**>
    type copy
    <store>
        type elasticsearch
        host localhost
        port 9200

        logstash_format true
        logstash_prefix logstash
        type_name dstat
        flush_interval 20
    </store>
</match>
__EOT__
fi
#===== Fluentd =====#

#===== Kibana =====#
echo "[*] Installing Kibana and Elastic..."
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
cat << __EOT__ >> /etc/yum.repos.d/kibana.repo
[kibana-5.x]
name=Kibana repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
__EOT__
yum update -y
yum install -y kibana elasticsearch

echo "[*] Enable & Start Kibana and elasticsearch ..."
systemctl enable elasticsearch
systemctl start elasticsearch

LIMIT=30
COUNT=0
while :
do
    COUNT=$(expr ${COUNT} + 1)
    if [ ${LIMIT} -le ${COUNT} ]
    then
        echo "Timeout Error"
        _motd fail
    fi
    if [ $(ss -an | grep "^tcp" | grep LISTEN | grep -c ":9200") -ne 0 ]
    then
        break
    fi
    sleep 10
done

systemctl enable kibana
systemctl start kibana
#===== Kibana =====#

sleep 60

#===== Change Logstash Template =====#
if [ $FLUENT_PLUGIN_DSTAT_ENABLED = "1" ]; then
    echo "[*] Change Logstash Template..."
    cat << __EOT__ | curl -XPUT http://localhost:9200/_template/logstash-tmpl -d @-
{
  "template": "logstash-*",
  "mappings": {
    "dstat": {
      "dynamic_templates": [
        {
          "string_to_double": {
            "match_mapping_type": "string",
            "path_match": "dstat.*",
            "mapping": { "type": "double" }
          }
        }
      ]
    }
  }
}
__EOT__
fi

echo "[*] Enable & Start td-agent..."
systemctl enable td-agent
systemctl start td-agent
echo "[+] success"
#===== Change Logstash Template =====#

#===== Nginx =====#
htpasswd -b -c /etc/nginx/.htpasswd ${BASIC_USER} ${BASIC_PASS}
cat << __EOT__ > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        root         /usr/share/nginx/html;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        location / {
                    proxy_pass http://localhost:5601/;
                    auth_basic "Restricted";
                    auth_basic_user_file /etc/nginx/.htpasswd;
        }

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
    }
}
__EOT__
systemctl enable nginx
systemctl start nginx
#===== Nginx =====#

echo "[+] Install Finished."
_motd end

