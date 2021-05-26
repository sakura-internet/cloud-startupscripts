#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- リポジトリの設定と rspamd, redis のインストール
curl -L -o /etc/yum.repos.d/rspamd.repo https://rspamd.com/rpm-stable/centos-8/rspamd.repo 
sed -i 's/http:/https:/' /etc/yum.repos.d/rspamd.repo
rpm --import https://rspamd.com/rpm/gpg.key || true
(dnf install -y rspamd || true)
dnf install -y redis

mkdir /etc/rspamd/local.d/keys

#-- rspamd の設定
cat <<'_EOL_'> /etc/rspamd/local.d/options.inc
filters = "chartable,dkim,spf,surbl,regexp,fuzzy_check";
check_all_filters = true;
max_message = 128Mb
_EOL_

cat <<'_EOL_'> /etc/rspamd/local.d/milter_headers.conf
#use = ["x-spamd-result","x-rspamd-server","x-rspamd-queue-id","authentication-results","x-spam-level","x-virus"];
use = ["authentication-results"];
authenticated_headers = ["authentication-results"];
_EOL_

cat <<_EOL_> /etc/rspamd/local.d/redis.conf
servers = "${REDIS_SERVER}";
_EOL_

cat <<'_EOL_'> /etc/rspamd/local.d/actions.conf
reject = null;
add_header = 6 ;
greylist = null;
_EOL_

cat <<'_EOL_'> /etc/rspamd/local.d/greylist.conf
enabled = false
_EOL_

cat <<'_EOL_'> /etc/rspamd/local.d/phishing.conf
openphish_enabled = true;
phishtank_enabled = true;
_EOL_

cat <<_EOL_> /etc/rspamd/local.d/antivirus.conf
clamav {
  action  = "reject";
  type    = "clamav";
  servers = "/var/run/clamd.scan/clamd.sock";
  symbol = "CLAM_VIRUS";
  patterns {
    #symbol_name = "pattern";
    JUST_EICAR = "^Eicar-Test-Signature$";
  }
}
_EOL_

usermod -aG clamscan _rspamd
usermod -aG virusgroup _rspamd

cat <<'_EOL_'> /etc/rspamd/local.d/url_reputation.conf
enabled = true;

# Key prefix for redis - default "Ur."
key_prefix = "Ur.";

# Symbols to insert - defaults as shown
symbols {
  white = "URL_REPUTATION_WHITE";
  black = "URL_REPUTATION_BLACK";
  grey = "URL_REPUTATION_GREY";
  neutral = "URL_REPUTATION_NEUTRAL";
}

# DKIM/DMARC/SPF allow symbols - defaults as shown
foreign_symbols {
  dmarc = "DMARC_POLICY_ALLOW";
  dkim = "R_DKIM_ALLOW";
  spf = "R_SPF_ALLOW";
}

# SURBL metatags to ignore - default as shown
ignore_surbl = ["URIBL_BLOCKED", "DBL_PROHIBIT", "SURBL_BLOCKED"];

# Amount of samples required for scoring - default 5
threshold = 5;

#Maximum number of TLDs to update reputation on (default 1)
update_limit = 1;

# Maximum number of TLDs to query reputation on (default 100)
query_limit = 100;

# If true, try to find most 'relevant' URL (default true)
relevance = true;
_EOL_

#-- DKIM
mkdir -p ${WORKDIR}/keys
for domain in ${DOMAIN_LIST}
do
  rspamadm dkim_keygen -d ${domain} -s default -b 2048 > ${WORKDIR}/keys/${domain}.keys
  head -28 ${WORKDIR}/keys/${domain}.keys > /etc/rspamd/local.d/keys/default.${domain}.key
  chmod 600 /etc/rspamd/local.d/keys/default.${domain}.key
  chown _rspamd. /etc/rspamd/local.d/keys/default.${domain}.key
done

cat <<'_EOL_'> /etc/rspamd/local.d/dkim_signing.conf
# メーリングリストや転送の対応
allow_hdrfrom_mismatch = true;
sign_local = true;

use_esld = false;
try_fallback = true;

_EOL_

for domain in ${DOMAIN_LIST} 
do
	cat <<-_EOL_>> /etc/rspamd/local.d/dkim_signing.conf
	domain {
	  ${domain} {
	    path = "/etc/rspamd/local.d/keys/\$selector.\$domain.key";
	    selector = "default";
	  }
	}
	_EOL_
done

cat <<_EOL_>> /etc/rspamd/local.d/dkim_signing.conf
#-- メーリングリストを使用しない場合
sign_headers = '(o)from:(o)sender:(o)reply-to:(o)subject:(o)date:(o)message-id:(o)to:(o)cc:(o)mime-version:(o)content-type:(o)content-transfer-encoding:resent-to:resent-cc:resent-from:resent-sender:resent-message-id:(o)in-reply-to:(o)references:list-id:list-owner:list-unsubscribe:list-subscribe:list-post';
_EOL_

cat <<'_EOL_'> /etc/rspamd/local.d/arc.conf
# メーリングリストや転送の対応
allow_hdrfrom_mismatch = true;
sign_local = true;
use_domain = "envelope";

use_esld = false;
try_fallback = true;

_EOL_

for domain in ${DOMAIN_LIST}
do
	cat <<-_EOL_>> /etc/rspamd/local.d/arc.conf
	domain {
	  ${domain} {
	    path = "/etc/rspamd/local.d/keys/\$selector.\$domain.key";
	    selector = "default";
	  }
	}
	_EOL_
done

cat <<_EOL_>> /etc/rspamd/local.d/arc.conf
#-- メーリングリストを使用しない場合
sign_headers = "(o)from:(o)sender:(o)reply-to:(o)subject:(o)date:(o)message-id:(o)to:(o)cc:(o)mime-version:(o)content-type:(o)content-transfer-encoding:resent-to:resent-cc:resent-from:resent-sender:resent-message-id:(o)in-reply-to:(o)references:list-id:list-owner:list-unsubscribe:list-subscribe:list-post:dkim-signature";
_EOL_

cat <<_EOL_> /etc/rspamd/local.d/history_redis.conf
servers         = ${REDIS_SERVER}:6379;
key_prefix      = "rs_history";
nrows           = 10000;
compress        = true;
subject_privacy = false;
_EOL_

cat <<_EOL_> /etc/rspamd/local.d/mime_types.conf
bad_extensions = {
    ace = 4,
    arj = 4,
    bat = 2,
    cab = 3,
    com = 2,
    exe = 1,
    jar = 2,
    lnk = 4,
    scr = 4,
};
bad_archive_extensions = {
    pptx = 0.1,
    docx = 0.1,
    xlsx = 0.1,
    pdf  = 0.1,
    jar  = 3,
    js   = 0.5,
    vbs  = 4,
};
archive_extensions = {
    zip = 1,
    arj = 1,
    rar = 1,
    ace = 1,
    7z  = 1,
    cab = 1,
};
_EOL_

#-- web interface のパスワード設定
web_passwd=$(rspamadm pw -p ${ROOT_PASSWORD})

cat <<_EOL_> /etc/rspamd/local.d/worker-controller.inc
password        = "${web_passwd}";
enable_password = "${web_passwd}";
_EOL_

#-- redis, rspamd の起動
systemctl enable redis rspamd
systemctl start redis rspamd

#-- nginx に設定追加
mkdir -p /etc/nginx/conf.d/https.d
cat <<'_EOL_' > /etc/nginx/conf.d/https.d/rspamd.conf
  location ^~ /rspamd {
    location /rspamd/ {
      proxy_pass       http://127.0.0.1:11334/;
      proxy_set_header Host      $host;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
  }
_EOL_

#-- dkim record 追加
for domain in ${DOMAIN_LIST}
do
  record=$(cat ${WORKDIR}/keys/${domain}.keys | tr -d '[\n\t]' | sed -e 's/"//g' -e 's/.* TXT ( //' -e 's/) ; $//')
  usacloud dns record-add -y --name default._domainkey --type TXT --value "${record}" ${domain}
done

