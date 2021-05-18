#!/bin/bash -e

source $(dirname $0)/../config.source

check_version() {
	PROC=$1
	VERSION=""
	case ${PROC} in
		os)
			VERSION=$(cat /etc/redhat-release)
			;;
		kernel)
			VERSION=$(uname --kernel-release)
			;;
		slapd)
			VERSION=$(/usr/sbin/slapd -V 2>&1 | awk '/^@/{print $4}')
			;;
		389ds)
			VERSION=$(/usr/sbin/ns-slapd -v 2>&1 | awk -F[/\ ] '/389-Directory/{print $2}')
			;;
		opendkim)
			VERSION=$(/usr/sbin/opendkim -V | awk '/^opendkim/{print $NF}')
			;;
		dovecot)
			VERSION=$(/usr/sbin/dovecot --version | awk '{print $1}')
			;;
		clamav-milter)
			VERSION=$(/usr/sbin/clamav-milter --version | awk '{print $NF}')
			;;
		clamd)
			VERSION=$(/usr/sbin/clamd --version -c /etc/clamd.d/scan.conf | awk -F[\ \/] '{print $2}')
			;;
		yenma)
			VERSION=$(/usr/local/yenma/libexec/yenma -h | head -1 | awk '{print $NF}')
			;;
		postfix)
			VERSION=$(/usr/sbin/postconf | awk '/^mail_version/{print $NF}')
			;;
		mysql)
			VERSION=$(/usr/bin/mysql --version | awk '{print $3}')
			;;
		php-fpm)
			VERSION=$(php-fpm -v | awk '/^PHP/{print $2}')
			;;
		nginx)
			VERSION=$(/usr/sbin/nginx -v 2>&1 | awk -F\/ '{print $NF}')
			;;
		roundcube)
			VERSION=$(awk '/Version/{print $3}' ${HTTPS_DOCROOT}/roundcube/index.php)
			;;
		phpldapadmin)
			VERSION=$(awk -F- '{print $NF}' ${HTTPS_DOCROOT}/phpldapadmin/VERSION)
			;;
		rainloop)
			VERSION=$(ls -dtr ${HTTPS_DOCROOT}/rainloop/rainloop/v/* | awk -F\/ '{print $NF}' | tail -1)
			;;
		rspamd)
			VERSION=$(rspamd --version | awk '{print $NF}')
			;;
		redis)
			VERSION=$(redis-server -v | awk '{print $3}' | awk -F= '{print $2}')
			;;
		sympa)
			which sympa.pl > /dev/null 2>&1
			if [ $? -eq 0 ]
			then
				VERSION=$(sympa.pl --version | awk '{print $NF}')
			else
				VERSION="not installed"
			fi
			;;
	esac
	echo "${PROC}: ${VERSION}"
}

check_proc() {
	PROC=$1
	USER=$2
	if [ $(ps -eo user,cmd | grep "^${USER} " | sed "s/${USER}//" | grep ${PROC} | grep -vc grep) -eq 0 ]
	then
		echo "ERROR: ${PROC}"
	elif [ "${PROC}" = "master" ]
	then 
		echo "OK: postfix"
	else
		echo "OK: ${PROC}"
	fi
}

check_dns() {
	RECODE=$1
	CLASS=$2
	RESULT=$(dig ${RECODE} ${CLASS} +short)
	if [ "${RESULT}x" = "x" ]
	then
		echo "ERROR: ${RECODE} ${CLASS}"
	else
		echo "OK: ${RECODE} ${CLASS} ${RESULT}"
	fi
}

check_cert() {
	DOMAIN=$1
	RESULT=$(openssl s_client -connect ${DOMAIN}:443 < /dev/null 2>/dev/null | openssl x509 -text 2>&1 | egrep "Before|After|DNS:" | sed -e 's/^ \+/ /' -e '1i Validity:' -e 's/^ DNS:/Subject Alternative Name:\n DNS:/')
	if [ "${RESULT}x" = "x" ]
	then
		echo "ERROR"
	else
		echo "${RESULT}"
	fi
}

echo "-- Application Version --"
for x in os 389ds dovecot clamd rspamd redis postfix mysql php-fpm nginx roundcube phpldapadmin
do
	check_version ${x}
done

echo

echo "-- Process Check --"
check_proc ns-slapd dirsrv 
check_proc dovecot dovecot
check_proc clamd clamscan
check_proc rspamd _rspamd
check_proc redis-server redis
check_proc master root
check_proc mysqld mysql
check_proc php-fpm nginx
check_proc nginx nginx

echo

for x in ${DOMAIN_LIST}
do
	HOST=$(hostname | sed "s/${FIRST_DOMAIN}/${x}/")
	echo "-- ${x} DNS Check --"
	check_dns ${x} A
	check_dns ${x} MX
	check_dns ${x} TXT
	if [ "${FIRST_DOMAIN}" = "${x}" ]
	then
		check_dns ${HOST} A
		check_dns autoconfig.${x} A
	else
		check_dns autoconfig.${x} CNAME
	fi
	check_dns _dmarc.${x} TXT
	check_dns _adsp._domainkey.${x} TXT
	check_dns default._domainkey.${x} TXT
	echo
done

echo "-- ${FIRST_DOMAIN} TLS Check --"
check_cert ${FIRST_DOMAIN}

echo

