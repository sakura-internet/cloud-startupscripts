#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- clamav のインストール
yum install -y clamav clamav-server-systemd clamav-update

#-- virus database の更新
freshclam

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
ArchiveBlockEncrypted no
_EOL_

mkdir /var/log/clamd
chown clamscan /var/log/clamd

#-- clamd の起動
systemctl enable clamd@scan 
systemctl start clamd@scan
