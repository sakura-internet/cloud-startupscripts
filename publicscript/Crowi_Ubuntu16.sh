#!/bin/bash
# @sacloud-once

# @sacloud-require-archive distro-ubuntu distro-ver-16.04.*

# @sacloud-desc-begin
#   Markdown形式で記述可能な組織用コミュニケーションツールCrowiをセットアップするスクリプトです。
#   サーバ作成後はブラウザより「http://サーバのIPアドレス/installer」にアクセスすることで設定が行えます。
#   （このスクリプトは、16.04 でのみ動作します）
# @sacloud-desc-end

set -x

apt update || exit 1

# install nodejs
apt install -y curl || exit 1
curl -sL https://deb.nodesource.com/setup_6.x -o nodesource_setup.sh
bash nodesource_setup.sh
apt install -y nodejs || exit 1

npm install -g npm

# install MongoDB
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
apt update || exit 1
apt install -y mongodb-org || exit 1

cat << EOF >> /etc/systemd/system/mongodb.service
[Unit]
Description=MongoDB Database Service
Wants=network.target
After=network.target

[Service]
ExecStart=/usr/bin/mongod --config /etc/mongod.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
User=mongodb
Group=mongodb
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF

systemctl status mongodb.service >/dev/null 2>&1 || systemctl start mongodb.service
for i in {1..5}; do
  sleep 1
  systemctl status mongodb.service && break
  [ "$i" -lt 5 ] || exit 1
done
systemctl enable mongodb.service || exit 1

apt install -y pwgen
PASSWD=$(pwgen -s 32 1)
cat << EOF >> /tmp/mongobat.js
db.createUser({user: "crowi", pwd: "$PASSWD", roles: [{role: "readWrite", db: "crowidb"}]});
EOF
mongo crowidb < /tmp/mongobat.js
rm -rf /tmp/mongobat.js

# install ElasticSerach
apt install -y openjdk-8-jre || exit 1
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add
echo "deb https://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
apt update || exit 1
apt install -y elasticsearch || exit 1
/usr/share/elasticsearch/bin/plugin install analysis-kuromoji

systemctl status elasticsearch.service >/dev/null 2>&1 || systemctl start elasticsearch.service
for i in {1..5}; do
  sleep 1
  systemctl status elasticsearch.service && break
  [ "$i" -lt 5 ] || exit 1
done
systemctl enable elasticsearch.service || exit 1

# install Crowi
apt install -y git build-essential libkrb5-dev || exit 1
git clone https://github.com/crowi/crowi.git /opt/crowi
cd /opt/crowi
npm install
npm run build

cat << EOF > /etc/systemd/system/crowi.service
[Unit]
Description=Crowi - The Simple & Powerful Communication Tool Based on Wiki
After=network.target mongodb.service

[Service]
WorkingDirectory=/opt/crowi
EnvironmentFile=/opt/crowi/crowi.conf
# Measures for failure at the first OS restart
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/node app.js

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /opt/crowi/crowi.conf
PASSWORD_SEED="yourpasswordseed"
MONGO_URI="mongodb://crowi:$PASSWD@localhost/crowidb"
FILE_UPLOAD="local"
PORT=3000
ELASTICSEARCH_URI="localhost:9200"
EOF

systemctl status crowi.service >/dev/null 2>&1 || systemctl start crowi.service
for i in {1..5}; do
  sleep 1
  systemctl status crowi.service && break
  [ "$i" -lt 5 ] || exit 1
done
systemctl enable crowi.service || exit 1

# nginx
apt install -y nginx || exit 1
systemctl stop nginx.service || exit 1

HOSTNAME="$(hostname).vs.sakura.ne.jp"
NGINX_CONFIGPATH="/etc/nginx/nginx.conf"
mv "$NGINX_CONFIGPATH" "${NGINX_CONFIGPATH}.origin"
cp "/opt/crowi/public/nginx.conf" "$NGINX_CONFIGPATH"
cp "/opt/crowi/public/nginx-mime.types" "/etc/nginx/nginx-mime.types"

sed -i -e "s/\r//g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(^user.*$\)@# \1\nuser       www-data;@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(^error_log.*$\)@# \1\nerror_log  /var/log/nginx/error.log;@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(^pid.*$\)@# \1\npid        /run/nginx.pid;@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(access_log.*access.log.*$\)@# \1\n  access_log   /var/log/nginx/access.log main;@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(listen\s80\sdefault_server;$\)@# \1\n    listen 80 default_server deferred;@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(server_name.*$\)@\1\n    server_name ${HOSTNAME};@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(root\s/sites/example.com/public;$\)@# \1\n    root /opt/crowi/public;\n\n    location / {\n      proxy_pass http://127.0.0.1:3000;\n      proxy_set_header Host \$host;\n      proxy_set_header X-Forwarded-For \$remote_addr;\n    }@g" "$NGINX_CONFIGPATH"
sed -i -e "s@\(access_log logs/static.log;$\)@# \1\n      access_log /var/log/nginx/static.log;@g" "$NGINX_CONFIGPATH"

systemctl start nginx.service || exit 1
systemctl enable nginx.service || exit 1

iptables -I INPUT 5 -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
iptables-save > "/etc/iptables/iptables.rules"

reboot
