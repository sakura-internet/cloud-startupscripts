#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- clamav のインストール
dnf install -y clamd clamav clamav-update

#-- virus database の更新
freshclam

mkdir /var/log/clamd
chown clamscan. /var/log/clamd
chmod 775 /var/log/clamd

#-- clamd の設定ファイルの作成
cp -p /etc/clamd.d/scan.conf{,.org}
cat <<_EOL_>/etc/clamd.d/scan.conf
LogFile /var/log/clamd/clamd.log
LogFileMaxSize 0
LogTime yes
LogSyslog yes
PidFile /var/run/clamd.scan/clamd.pid
TemporaryDirectory /var/tmp
DatabaseDirectory /var/lib/clamav
LocalSocket /var/run/clamd.scan/clamd.sock
FixStaleSocket yes
MaxConnectionQueueLength 30
MaxThreads 50
ReadTimeout 300
User clamscan
ScanPE yes
ScanELF yes
ScanOLE2 yes
ScanMail yes
ScanArchive yes
AlertEncrypted yes
StreamMaxLength 128M
_EOL_

#-- clamd の起動設定
systemctl enable clamd@scan clamav-freshclam
systemctl start clamd@scan
