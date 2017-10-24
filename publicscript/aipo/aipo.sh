#!/bin/bash
#
# @sacloud-name "Aipo"
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトは オープンソース グループウェア Aipo をセットアップします
# (このスクリプトは CentOS7.Xでのみ動作します)
#
# URLは http://IPアドレス です
# @sacloud-desc-end

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

# package install
yum remove -y epel-release
yum install -y epel-release
yum install -y gcc nmap lsof unzip readline-devel zlib-devel nginx
curl -o aipo-8.1.1-linux-x64.tar.gz -L 'https://ja.osdn.net/projects/aipo/downloads/64847/aipo-8.1.1-linux-x64.tar.gz/'
tar xpf aipo-8.1.1-linux-x64.tar.gz
cd aipo-8.1.1-linux-x64
sh installer.sh /usr/local/aipo

# systemd setting
cat <<_EOL_> /etc/systemd/system/aipo.service
[Unit]
Description=Groupwear Aipo
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/usr/local/aipo/bin/startup.sh
ExecStop=/usr/local/aipo/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
_EOL_

systemctl enable aipo.service nginx.service

sed -i 's/^TOMCAT_PORT=80/TOMCAT_PORT=8080/' /usr/local/aipo/conf/tomcat.conf
sed -i 's/port="80"/port="8080"/' /usr/local/aipo/tomcat/conf/server.xml

cat <<'_EOL_'> /etc/nginx/conf.d/aipo.conf
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    server_name _;
    root /usr/local/aipo/tomcat/webapps/ROOT/;

    location ~ "^(/themes/|/images/|/javascript/)" {
        root /usr/local/aipo/tomcat/webapps/ROOT/;
    }

    location / {
        try_files $uri @aipo;
    }

    location /push/ {
        try_files $uri @push;
    }

    location @aipo {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-Server $host;
        proxy_connect_timeout 90;
        proxy_send_timeout 90;
        proxy_read_timeout 90;
        proxy_buffers 4 32k;
        client_max_body_size 8m;
        client_body_buffer_size 128k;
    }

    location @push {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-Server $host;
        proxy_connect_timeout 90;
        proxy_send_timeout 86400;
        proxy_read_timeout 86400;
        proxy_buffers 4 32k;
        client_max_body_size 8m;
        client_body_buffer_size 128k;
    }
}
_EOL_

cp /etc/nginx/nginx.conf{,.org}
cat /etc/nginx/nginx.conf.org | perl -ne \
'{
  if(/^    }/&&$comment){
    print "#$_";
    $comment = 0;
  } elsif (/^    server/||$comment){
    print "#$_";
    $comment = 1;
  } else {
    print;
  }
}' > /etc/nginx/nginx.conf

firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload

systemctl start aipo nginx

sleep 5
curl -s 'http://127.0.0.1' &

_motd end

