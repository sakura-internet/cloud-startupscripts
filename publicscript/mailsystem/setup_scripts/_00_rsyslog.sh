#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- rsyslog の ratelimit を無効化
sed -i '/^module(load="imjournal"/a \       ratelimit.interval="0"' /etc/rsyslog.conf
