#!/bin/bash
#
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトはmastodonをセットアップします。
# (このスクリプトは、CentOS7.Xでのみ動作します。)
#
# 事前作業として以下の2つが必要となります
# ・さくらのクラウドDNSにゾーン登録を完了していること
# ・さくらのクラウドAPIのアクセストークンを取得していること
# ブラウザからアクセスできるようになるまでに30分程度のお時間がかかります。
# https://(さくらのクラウドDNSのゾーン名)
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-7
# @sacloud-text required ZONE "さくらのクラウドDNSで管理しているDNSゾーン" ex="example.com"
# @sacloud-apikey required permission=create AK "APIキー"

KEY="${SACLOUD_APIKEY_ACCESS_TOKEN}:${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}"

set -x
source /etc/sysconfig/network-scripts/ifcfg-eth0
DOMAIN="@@@ZONE@@@"
MADDR=mastodon@${DOMAIN}

# ログのリンクを作成
ln -s $(find /root/.sacloud-api/notes/*log) /tmp/startup_script.log

# リポジトリの設定
yum install -y yum-utils
yum-config-manager --enable epel
yum install -y http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm
curl -sL https://rpm.nodesource.com/setup_6.x | bash -

# パッケージのアップデートとインストール
yum update -y
yum install -y ImageMagick ffmpeg redis rubygem-redis postgresql-{server,devel,contrib} authd nodejs {openssl,readline,zlib,libxml2,libxslt,protobuf,ffmpeg}-devel protobuf-compiler nginx jq bind-utils
npm install -g yarn

# DNS登録
if [ $(dig ${DOMAIN} ns +short | egrep -c '^ns[0-9]+.gslb[0-9]+.sakura.ne.jp.$') -ne 2 ]
then
 echo "お客様ドメインのNSレコードにさくらのクラウドDNSが設定されておりません"
 exit 1
fi

ZONE=$(jq -r ".Zone.Name" /root/.sacloud-api/server.json)
BASE=https://secure.sakura.ad.jp/cloud/zone/${ZONE}/api/cloud/1.1
API=${BASE}/commonserviceitem/
RESJS=resource.json
DNSJS=dns.json
set +x
curl -s --user "${KEY}" ${API} | jq -r ".CommonServiceItems[] | select(.Status.Zone == \"${DOMAIN}\")" > ${RESJS} 2>/dev/null
set -x
RESID=$(jq -r .ID ${RESJS})
BLANK=$(jq -r ".Settings.DNS.ResourceRecordSets" ${RESJS})
if [ $(echo "${BLANK}" | grep -c "^\[\]$") -ne 1 ]
then
 if [ "${BLANK}x" = "x" ]
 then
  echo "リソースIDが取得できません、APIキーとドメインを確認してください"
  exit 1
 else
  echo "レコードを登録していないドメインを指定してください"
  exit 1
 fi
fi

API=${API}${RESID}
cat <<_EOL_> ${DNSJS}
{
 "CommonServiceItem": {
  "Settings": {
   "DNS":  {
    "ResourceRecordSets": [
     { "Name": "@", "Type": "A", "RData": "${IPADDR}" },
     { "Name": "@", "Type": "MX", "RData": "10 ${DOMAIN}." },
     { "Name": "@", "Type": "TXT", "RData": "v=spf1 +ip4:${IPADDR} -all" }
    ]
   }
  }
 }
}
_EOL_

set +x
curl -s --user "${KEY}" -X PUT -d "$(cat ${DNSJS} | jq -c .)" ${API} |jq "."
set -x

# postgresql, redis
export PGSETUP_INITDB_OPTIONS="--encoding=UTF-8 --no-locale"
postgresql-setup initdb
sed -i "s/ident/trust/" /var/lib/pgsql/data/pg_hba.conf
systemctl enable postgresql redis
systemctl start postgresql redis
su - postgres -c "createuser --createdb mastodon"

# ruby, mastodon
useradd mastodon
SETUP=/home/mastodon/setup.sh
cat << _EOF_ > ${SETUP}
set -x
git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
echo 'export PATH="~/.rbenv/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
rbenv init - >> ~/.bash_profile
source ~/.bash_profile
git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
rbenv install 2.4.1
rbenv global 2.4.1
rbenv rehash

git clone https://github.com/tootsuite/mastodon.git live
cd live
git checkout \$(git tag|grep -v rc|tail -n 1)
gem install bundler
bundle install --deployment --without development test
yarn install --pure-lockfile
cp .env.production.sample .env.production
export RAILS_ENV=production
SECRET_KEY_BASE=\$(bundle exec rake secret)
PAPERCLIP_SECRET=\$(bundle exec rake secret)
OTP_SECRET=\$(bundle exec rake secret)
sed -i -e "s/_HOST=[rd].*/_HOST=localhost/" \
-e "s/=postgres$/=mastodon/" \
-e "s/^LOCAL_DOMAIN=.*/LOCAL_DOMAIN=${DOMAIN}/" \
-e "s/^LOCAL_HTTPS.*/LOCAL_HTTPS=true/" \
-e "s/^SMTP_SERVER.*/SMTP_SERVER=localhost/" \
-e "s/^SMTP_PORT=587/SMTP_PORT=25/" \
-e "s/^SMTP_LOGIN/#SMTP_LOGIN/" \
-e "s/^SMTP_PASSWORD/#SMTP_PASSWORD/" \
-e "s/^#SMTP_AUTH_METHOD.*/SMTP_AUTH_METHOD=none/" \
-e "s/^SMTP_FROM_ADDRESS=.*/SMTP_FROM_ADDRESS=${MADDR}/" \
-e "s/^SECRET_KEY_BASE=/SECRET_KEY_BASE=\$(printf \${SECRET_KEY_BASE})/" \
-e "s/^PAPERCLIP_SECRET=/PAPERCLIP_SECRET=\$(printf \${PAPERCLIP_SECRET})/" \
-e "s/^OTP_SECRET=/OTP_SECRET=\$(printf \${OTP_SECRET})/" .env.production

bundle exec rails db:setup
bundle exec rails assets:precompile
_EOF_

chmod 755 ${SETUP}
chown mastodon. ${SETUP}
su - mastodon -c "/bin/bash ${SETUP}"

SDIR=/etc/systemd/system
cat << "_EOF_" > ${SDIR}/mastodon-web.service
[Unit]
Description=mastodon-web
After=network.target

[Service]
Type=simple
User=mastodon
WorkingDirectory=/home/mastodon/live
Environment="RAILS_ENV=production"
Environment="PORT=3000"
ExecStart=/home/mastodon/.rbenv/shims/bundle exec puma -C config/puma.rb
TimeoutSec=15
Restart=always

[Install]
WantedBy=multi-user.target
_EOF_

cat << "_EOF_" > ${SDIR}/mastodon-sidekiq.service
[Unit]
Description=mastodon-sidekiq
After=network.target

[Service]
Type=simple
User=mastodon
WorkingDirectory=/home/mastodon/live
Environment="RAILS_ENV=production"
Environment="DB_POOL=5"
ExecStart=/home/mastodon/.rbenv/shims/bundle exec sidekiq -c 5 -q default -q mailers -q pull -q push
TimeoutSec=15
Restart=always

[Install]
WantedBy=multi-user.target
_EOF_

cat << "_EOF_" > ${SDIR}/mastodon-streaming.service
[Unit]
Description=mastodon-streaming
After=network.target

[Service]
Type=simple
User=mastodon
WorkingDirectory=/home/mastodon/live
Environment="NODE_ENV=production"
Environment="PORT=4000"
ExecStart=/usr/bin/npm run start
TimeoutSec=15
Restart=always

[Install]
WantedBy=multi-user.target
_EOF_

systemctl enable mastodon-{web,sidekiq,streaming}
systemctl start mastodon-{web,sidekiq,streaming}

echo "5 0 * * * mastodon cd /home/mastodon/live && RAILS_ENV=production /home/mastodon/.rbenv/shims/bundle exec rake mastodon:daily 2>&1 | logger -t mastodon-daily -p local0.info" > /etc/cron.d/mastodon

# nginx
sed -i 's/user nginx/user mastodon/' /etc/nginx/nginx.conf
chown -R mastodon. /var/{lib,log}/nginx
sed -i 's/create 0644 nginx nginx/create 0644 mastodon mastodon/' /etc/logrotate.d/nginx

cat << _EOF_ > /etc/nginx/conf.d/https.conf
map \$http_upgrade \$connection_upgrade {
 default upgrade;
 ''      close;
}
server {
 listen 443 ssl http2 default_server;
 server_name ${DOMAIN};

 ssl_protocols TLSv1.2;
 ssl_ciphers EECDH+AESGCM:EECDH+AES;
 ssl_ecdh_curve prime256v1;
 ssl_prefer_server_ciphers on;
 ssl_session_cache shared:SSL:10m;
 ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
 ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

 keepalive_timeout 70;
 sendfile on;
 client_max_body_size 0;
 root /home/mastodon/live/public;
 server_tokens off;
 charset utf-8;

 gzip on;
 gzip_disable "msie6";
 gzip_vary on;
 gzip_proxied any;
 gzip_comp_level 6;
 gzip_buffers 16 8k;
 gzip_http_version 1.1;
 gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
 add_header Strict-Transport-Security "max-age=31536000";

 location / {
  try_files \$uri @proxy;
 }
 
 location ~ ^/(packs|system/media_attachments/files|system/accounts/avatars) {
  add_header Cache-Control "public, max-age=31536000, immutable";
  try_files \$uri @proxy;
 }
        
 location @proxy {
  proxy_set_header Host \$host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto https;
  proxy_set_header Proxy "";
  proxy_pass_header Server;
  proxy_pass http://127.0.0.1:3000;
  proxy_buffering off;
  proxy_redirect off;
  proxy_http_version 1.1;
  proxy_set_header Upgrade \$http_upgrade;
  proxy_set_header Connection \$connection_upgrade;

  tcp_nodelay on;
 }

 location /api/v1/streaming {
  proxy_set_header Host \$host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto https;
  proxy_set_header Proxy "";
  proxy_pass http://localhost:4000;
  proxy_buffering off;
  proxy_redirect off;
  proxy_http_version 1.1;
  proxy_set_header Upgrade \$http_upgrade;
  proxy_set_header Connection \$connection_upgrade;

  tcp_nodelay on;
 }

 error_page 500 501 502 503 504 /500.html;
}
_EOF_

# postfix
cat <<_EOL_>> /etc/postfix/main.cf
myhostname = ${DOMAIN}
smtp_tls_CAfile = /etc/pki/tls/certs/ca-bundle.crt
smtp_tls_security_level = may
smtp_tls_loglevel = 1
smtpd_client_connection_count_limit = 5
smtpd_client_message_rate_limit = 5
smtpd_client_recipient_rate_limit = 5
disable_vrfy_command = yes
smtpd_discard_ehlo_keywords = dsn, enhancedstatuscodes, etrn
_EOL_
sed -i -e 's/^inet_interfaces.*/inet_interfaces = all/' -e 's/^inet_protocols = all/inet_protocols = ipv4/' /etc/postfix/main.cf

systemctl restart postfix

# firewall
firewall-cmd --permanent --add-port=25/tcp --add-port=443/tcp
firewall-cmd --reload

# Lets Encrypt
cd /usr/local
git clone https://github.com/certbot/certbot
export PATH=/usr/local/certbot:${PATH}
CERT=/etc/letsencrypt/live/${DOMAIN}/fullchain.pem
CA="certbot-auto -n certonly --standalone -d ${DOMAIN} -m ${MADDR} --agree-tos"
${CA}
for x in $(seq 1 5)
do
 if [ ! -f ${CERT} ]
 then
  ${CA}
  sleep 300
 else
  continue
 fi
done

if [ ! -f ${CERT} ]
then
 echo "証明書の取得に失敗しました"
 exit 1
fi

echo "$((${RANDOM}%60)) $((${RANDOM}%24)) 1 * * root /usr/local/certbot/certbot-auto renew --webroot --webroot-path /home/mastodon/live/public --force-renew && /bin/systemctl reload nginx" > /etc/cron.d/certbot-auto

systemctl enable nginx
systemctl start nginx

# PTR 登録
API=${BASE}/ipaddress/${IPADDR}
cd /root/.sacloud-api/notes
PTRJS=ptr.json
cat <<_EOL_> ${PTRJS}
{
 "IPAddress": { "HostName": "${DOMAIN}" }
}
_EOL_
set +x
curl -s --user "${KEY}" -X PUT -d "$(cat ${PTRJS} | jq -c .)" ${API} |jq "."
BLANK=$(curl -s --user "${KEY}" -X GET ${API} | jq -r "select(.IPAddress.HostName == \"${DOMAIN}\") | .is_ok")
set -x

if [ "${BLANK}x" != "truex" ]
then
 echo "逆引きの登録に失敗しました"
 exit 1
fi

echo "セットアップが完了しました"