#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

yum install -y clamav-milter-systemd clamav-server-systemd clamav clamav-update

sed -i 's/^Example/#Example/' /etc/freshclam.conf
freshclam &

mkdir /var/log/clamd
chown root:clamilt /var/log/clamd
chmod 775 /var/log/clamd

cat <<_EOL_>/etc/clamd.d/scan.conf
LogFile /var/log/clamd/clamd.log
LogFileMaxSize 0
LogTime yes
LogSyslog yes
PidFile /var/run/clamav-milter/clamd.pid
TemporaryDirectory /var/tmp
DatabaseDirectory /var/lib/clamav
LocalSocket /var/run/clamav-milter/clamd.sock
FixStaleSocket yes
MaxConnectionQueueLength 30
MaxThreads 50
ReadTimeout 300
User clamilt
AllowSupplementaryGroups yes
ScanPE yes
ScanELF yes
DetectBrokenExecutables yes
ScanOLE2 yes
ScanMail yes
ScanArchive yes
ArchiveBlockEncrypted no
_EOL_

cat <<_EOL_>>/lib/systemd/system/clamd\@.service

[Install]
WantedBy = multi-user.target
_EOL_

systemctl enable clamd@scan
systemctl start clamd@scan

cat <<_EOL_>/etc/mail/clamav-milter.conf
MilterSocket inet:${CLAMAV_PORT}@${CLAMAV_SERVER}
MilterSocketMode 666
User clamilt
AllowSupplementaryGroups yes
ClamdSocket unix:/var/run/clamav-milter/clamd.sock
AddHeader Replace
LogFile /var/log/clamd/clamav-milter.log
LogFileMaxSize 0
LogTime yes
LogSyslog yes
_EOL_

rm -f /var/log/clamav-milter.log

sed -i '$d' /etc/sysconfig/freshclam

systemctl enable clamav-milter
systemctl start clamav-milter

cp -p script/remove_hold_queue.sh /usr/local/bin/remove_hold_queue.sh
sed -i "s/_DOMAIN_/${FIRST_DOMAIN}/" /usr/local/bin/remove_hold_queue.sh
chmod 755 /usr/local/bin/remove_hold_queue.sh

# ウィルス判定されたメールの削除と、削除通知の送信
echo "* * * * * root /usr/local/bin/remove_hold_queue.sh >/dev/null 2>&1" >> /etc/cron.d/startup-script-cron
