#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

if [ -z ${COCKPIT} ]
then
  exit 0
fi

#-- cockpit インストール
dnf -y install cockpit cockpit-storaged

#-- cockpit 設定
cat <<_EOL_> /etc/cockpit/cockpit.conf
[WebService]
Origins = https://${FIRST_DOMAIN} wss://${FIRST_DOMAIN}
ProtocolHeader = X-Forwarded-Proto
UrlRoot=/cockpit
_EOL_

#-- nginx 設定
cat <<'_EOL_'> /etc/nginx/conf.d/https.d/cockpit.conf
  location ^~ /cockpit {
    location /cockpit/ {
      # Required to proxy the connection to Cockpit
      proxy_pass       https://127.0.0.1:9090/cockpit/;
      proxy_set_header Host      $host;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;

      # Required for web sockets to function
      proxy_http_version 1.1;
      proxy_buffering off;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";

      # Pass ETag header from Cockpit to clients.
      # See: https://github.com/cockpit-project/cockpit/issues/5239
      gzip off;
    }
  }
_EOL_

#-- 389-ds の cockpit plugin 対応
dnf -y module install 389-directory-server:stable/default

cat <<_EOL_>>/usr/lib/systemd/system/cockpit.service

[Install]
WantedBy=multi-user.target
_EOL_

systemctl daemon-reload
systemctl enable cockpit

