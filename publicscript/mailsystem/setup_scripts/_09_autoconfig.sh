#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

mkdir -p ${HTTPS_DOCROOT}/emailsetting
chown -R nginx. ${HTTPS_DOCROOT}/emailsetting

#-- thunderbird
cp -p $(dirname $0)/../tools/autoconfig.php ${HTTPS_DOCROOT}/emailsetting

cat <<'_EOL_' > /etc/nginx/conf.d/https.d/emailsetting.conf
  #-- thunderbird
  location ^~ /mail/config-v1.1.xml {
    try_files /emailsetting/autoconfig.php =404;
    fastcgi_pass unix:/run/php-fpm/www.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
    include fastcgi_params;
  }
_EOL_
