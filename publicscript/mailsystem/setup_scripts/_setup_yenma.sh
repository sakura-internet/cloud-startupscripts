#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

yum install -y openssl-devel ldns-devel sendmail-devel

ENMAGID=10001
ENMAUID=10001

mkdir -p ${WORKDIR}/build
cd ${WORKDIR}/build
git clone https://github.com/iij/yenma.git
cd yenma
./configure --prefix=/usr/local/yenma-2.0.0-beta4
make > /dev/null
make install
ln -s yenma-2.0.0-beta4 /usr/local/yenma

groupadd -g ${ENMAGID} yenma
useradd -u ${ENMAUID} -g yenma yenma

mkdir /run/yenma
chown yenma. /run/yenma

echo "d /run/yenma 0755 yenma yenma" > /etc/tmpfiles.d/yenma.conf

curl -o /etc/mail/effective_tld_names.dat https://publicsuffix.org/list/effective_tld_names.dat

cat <<_EOL_>/etc/mail/yenma.conf
Service.User: yenma
Service.PidFile: /run/yenma/yenma.pid
Service.ExclusionBlocks: 127.0.0.1,::1
Logging.Facility: mail
Logging.Ident: yenma
Logging.Mask: info
Milter.Socket: inet:${ENMA_PORT}@${ENMA_SERVER}
Milter.Backlog: 100
Milter.Timeout: 180
Milter.DebugLevel: 0
Milter.LazyQidFetch: true
## Authentication-Results header
AuthResult.UseSpfHardfail: false
## SPF verification
SPF.Verify: true
SPF.LookupSPFRR: false
## Sender ID verification
SIDF.Verify: true
## DKIM verification
Dkim.Verify: true
# the limit of the number of signature headers per message
Dkim.SignHeaderLimit: 5
Dkim.AcceptExpiredSignature: false
Dkim.Rfc4871Compatible: false
DkimAdsp.Verify: true
## DMARC
Dmarc.Verify: true
Dmarc.PublicSuffixList: /etc/mail/effective_tld_names.dat
Dmarc.RejectAction: none
#Dmarc.RejectAction: reject
#Dmarc.RejectReplyCode: 550
#Dmarc.RejectEnhancedStatusCode: 5.7.1
#Dmarc.RejectMessage: Email rejected per DMARC policy
_EOL_

cat <<_EOL_>/etc/systemd/system/yenma.service
[Unit]
Description=email verify SPF and DKIM and DMARC
After=syslog.target network.target

[Service]
Type=forking
PIDFile=/run/yenma/yenma.pid
ExecStart=/usr/local/yenma/libexec/yenma -c /etc/mail/yenma.conf
ExecReload=/bin/kill -HUP $MAINPID
PrivateTmp=true
NonBlocking=yes

[Install]
WantedBy=multi-user.target
_EOL_

systemctl enable yenma
systemctl start yenma
