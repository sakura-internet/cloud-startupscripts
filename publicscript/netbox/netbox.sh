#!/bin/bash
# @sacloud-name "NetBox"
# @sacloud-once
# @sacloud-require-archive distro-ubuntu distro-ver-20.04.*
#
# @sacloud-desc-begin
#  NetBoxをインストールするスクリプトです。
#  このスクリプトは Ubuntu 20.04 でのみ動作します。
#  このスクリプトは完了までに10分程度時間がかかります。
# @sacloud-desc-end
#
# @sacloud-text HOSTNAME "WebブラウザでアクセスするURIを入力してください。(defaultでホスト名が入ります。)"
# @sacloud-password required maxlen=50 PASSWORD "NetBoxDBのパスワードを入力してください。"
# @sacloud-text required WEB_USER "WEB-UIでのログインユーザを入力してください。"
# @sacloud-password required WEB_PASS "WEB-UIでのログインパスワードを入力してください。"

set -eux

PASSWORD=@@@PASSWORD@@@
HOSTNAME=@@@HOSTNAME@@@

if [ "$HOSTNAME" == "" ] ;then
  HOSTNAME="$(hostname -A | tr -d " ")"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update

# postgresql
apt-get install -y postgresql libpq-dev

systemctl start postgresql

su - postgres -c "psql <<_EOL_
CREATE DATABASE netbox;
CREATE USER netbox WITH PASSWORD '$PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE netbox TO netbox;
_EOL_
"

# redis
echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
echo "net.core.somaxconn = 511" >> /etc/sysctl.conf
sysctl -p

cat << _EOF_ >> /etc/systemd/system/disable-transparent-huge-pages.service
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=redis-server.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'

[Install]
WantedBy=multi-user.target
_EOF_

systemctl daemon-reload
systemctl start disable-transparent-huge-pages
systemctl enable disable-transparent-huge-pages

apt-get install -y redis-server

# netbox
apt-get install -y python3 python3-pip python3-venv python3-dev build-essential libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev curl jq

pip3 install --upgrade pip

VERSION=$(curl --silent https://api.github.com/repos/netbox-community/netbox/releases/latest | jq --raw-output .tag_name | tr -d v)
wget https://github.com/netbox-community/netbox/archive/v${VERSION}.tar.gz
tar -xzf v${VERSION}.tar.gz -C /opt
rm -f v${VERSION}.tar.gz
ln -s /opt/netbox-${VERSION}/ /opt/netbox

adduser --system --group netbox
chown --recursive netbox /opt/netbox/netbox/media/

pip3 install napalm

cd /opt/netbox/netbox/netbox/
cp configuration.example.py configuration.py

SECRET_KEY=$(python3 /opt/netbox/netbox/generate_secret_key.py)

sed -i -e "s/^ALLOWED_HOSTS.*$/ALLOWED_HOSTS = ['$HOSTNAME']/" configuration.py
sed -i -e "s/'USER': ''.*# PostgreSQL username/'USER': 'netbox',/" configuration.py
sed -i -e "s/'PASSWORD': ''.*# PostgreSQL password/'PASSWORD': '$PASSWORD',/" configuration.py
sed -i -e "s/SECRET_KEY = ''/SECRET_KEY = '$SECRET_KEY'/" configuration.py

/opt/netbox/upgrade.sh

source /opt/netbox/venv/bin/activate
cd /opt/netbox/netbox
python3 manage.py createsuperuser

apt-get install -y expect

expect -c "
set timeout 5
spawn python3 manage.py createsuperuser
expect {
    \"Username (leave blank to use 'root'):\" {
        send \"@@@WEB_USER@@@\n\"
        exp_continue
    }
    \"Email address:\" {
        send \"\n\"
        exp_continue
    }
    \"Password:\" {
        send \"@@@WEB_PASS@@@\n\"
        exp_continue
    }
    \"Password (again):\" {
        send \"@@@WEB_PASS@@@\n\"
        exp_continue
    }
}
"

# gunicorn
cd /opt/netbox
cp contrib/gunicorn.py /opt/netbox/gunicorn.py
cp contrib/*.service /etc/systemd/system/

systemctl daemon-reload
systemctl start netbox netbox-rq
systemctl enable netbox netbox-rq

# nginx
apt-get install -y nginx

cat << '_EOF_' >> /etc/nginx/sites-available/netbox
server {
    listen 80;
    server_name _HOSTNAME_;
    client_max_body_size 25m;
    location /static/ {
        alias /opt/netbox/netbox/static/;
    }
    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header X-Forwarded-Host $server_name;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
_EOF_

sed -i -e "s/_HOSTNAME_/$HOSTNAME/" /etc/nginx/sites-available/netbox

cd /etc/nginx/sites-enabled/
rm default
ln -s /etc/nginx/sites-available/netbox

systemctl restart nginx

# firewall
rm -f /etc/iptables/iptables.rules
rm -f /etc/network/if-pre-up.d/iptables

ufw allow 22
ufw allow 80
ufw default deny
ufw --force enable
