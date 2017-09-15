#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

# install package
yum install -y openldap-servers openldap-clients sendmail-cf

# set up openldap
cat <<'_EOL_'> /var/lib/ldap/DB_CONFIG
set_cachesize 0 10485760 1
set_flags DB_LOG_AUTOREMOVE
set_lg_regionmax 262144
set_lg_bsize 2097152
_EOL_

DOMAIN=$(echo ${ROOT_DN} | sed 's/^cn=admin,//' | sed 's/dc=//g' | sed 's/,/./g')
ROOT_PW=$(slappasswd -s ${ROOT_PASSWORD})

cp -p /usr/share/sendmail-cf/sendmail.schema /etc/openldap/schema/

cat <<_EOL_> /etc/openldap/slapd.conf
loglevel 0x4100
sizelimit -1
include  /etc/openldap/schema/corba.schema
include  /etc/openldap/schema/core.schema
include  /etc/openldap/schema/cosine.schema
include  /etc/openldap/schema/duaconf.schema
include  /etc/openldap/schema/dyngroup.schema
include  /etc/openldap/schema/inetorgperson.schema
include  /etc/openldap/schema/java.schema
include  /etc/openldap/schema/misc.schema
include  /etc/openldap/schema/nis.schema
include  /etc/openldap/schema/openldap.schema
include  /etc/openldap/schema/ppolicy.schema
include  /etc/openldap/schema/collective.schema
include  /etc/openldap/schema/sendmail.schema
allow bind_v2
pidfile  /var/run/openldap/slapd.pid
argsfile /var/run/openldap/slapd.args
moduleload syncprov.la
access to attrs=UserPassword
	by dn="${ROOT_DN}" write
	by self write
	by anonymous auth
	by * none
access to dn.regex="uid=.*,ou=Disable,dc=.*"
	by * none
access to filter="(|(objectClass=organization)(objectClass=organizationalRole)(objectClass=organizationalUnit))"
	by * none
access to *
	by * read
database config
access to *
	by dn.exact="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage
	by * none
database monitor
access to *
	by dn.exact="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read
	by dn.exact="${ROOT_DN}" read
	by * none
database bdb
suffix  ""
checkpoint 1024 15
rootdn  "${ROOT_DN}"
rootpw  "${ROOT_PW}"
directory /var/lib/ldap
index objectClass   eq,pres
index uid           eq,pres,sub
index mailHost,mailRoutingAddress,mailLocalAddress,userPassword,sendmailMTAHost eq,pres
_EOL_

sed -i "s#^SLAPD_URLS=.*#SLAPD_URLS=\"ldap://${LDAP_MASTER}/\"#" /etc/sysconfig/slapd
mv /etc/openldap/slapd.d /etc/openldap/slapd.d.org
# yum update などで slapd.d が復活すると起動しなくなるので定期的に確認して削除
echo "* * * * * root rm -rf /etc/openldap/slapd.d" > /etc/cron.d/startup-script-cron

# setup syslog
echo "local4.*  /var/log/openldaplog" > /etc/rsyslog.d/openldap.conf
sed -i '1s#^#/var/log/openldaplog\n#' /etc/logrotate.d/syslog
systemctl restart rsyslog

# start slapd
systemctl enable slapd
systemctl start slapd

mkdir -p ${WORKDIR}/ldap

# setup directory manager
TMPDN=""
for x in $(for y in $(echo "${DOMAIN}" | sed 's/\./ /g')
do
	echo ${y}
done | tac) 
do
	TMPDN="dc=${x}${TMPDN}"
	cat <<-_EOL_>>${WORKDIR}/ldap/init.ldif
	dn: ${TMPDN}
	objectClass: dcObject
	objectClass: organization
	dc: ${x}
	o: SAKURA Internet Inc.
	
	_EOL_
	TMPDN=",${TMPDN}"
done

cat <<_EOL_>>${WORKDIR}/ldap/init.ldif
dn: ${ROOT_DN}
objectclass: organizationalRole
cn: admin
description: Directory Manager
_EOL_

ldapadd -x -h ${LDAP_MASTER} -D "${ROOT_DN}" -w ${ROOT_PASSWORD} -f ${WORKDIR}/ldap/init.ldif

