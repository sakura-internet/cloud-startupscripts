#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

yum install -y opendkim openssl openssl-devel

DLIST=$(ldapsearch -x mailroutingaddress | awk -F@ '/^mailRoutingAddress/{print $2}' | sort | uniq | perl -ne '{chomp; print "$_, "}' | sed 's/, $//')
sed -i "s/^Mode.*/Mode	s/" /etc/opendkim.conf
sed -i "s/^Socket.*/Socket	inet:${DKIM_PORT}@${DKIM_SERVER}/" /etc/opendkim.conf
sed -i "s/^# Domain.*example.com/Domain ${DLIST}/" /etc/opendkim.conf

opendkim-genkey --bit=1024 -D /etc/opendkim/keys -s default
chown opendkim. /etc/opendkim/keys/default.private

systemctl enable opendkim
systemctl start opendkim
