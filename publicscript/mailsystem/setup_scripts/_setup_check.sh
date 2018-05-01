#!/bin/bash 
set -e

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
			VERSION=$(/usr/bin/mysql --version | sed -e 's/, .*//' -e 's/^.*Ver/Ver/')
			;;
		php-fpm)
			VERSION=$(/usr/sbin/php-fpm -v | awk '/^PHP/{print $2}')
			;;
		nginx)
			VERSION=$(/usr/sbin/nginx -v 2>&1 | awk -F\/ '{print $NF}')
			;;
		roundcube)
			VERSION=$(awk '/Version/{print $3}' /usr/share/roundcubemail/index.php)
			;;
		phpldapadmin)
			VERSION=$(awk -F- '{print $NF}' /usr/share/phpldapadmin/VERSION)
			;;
		rainloop)
			VERSION=$(ls -dtr ${HTTPS_DOCROOT}/rainloop/rainloop/v/* | awk -F\/ '{print $NF}' | tail -1)
			;;
	esac
	echo "${PROC}: ${VERSION}"
}

check_proc() {
	PROC=$1
	USER=$2
	if [ $(ps -eo user,cmd | grep "^${USER} " | grep ${PROC} | grep -vc grep ) -eq 0 ]
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
	RESULT=$(openssl s_client -connect ${DOMAIN}:443 < /dev/null 2>/dev/null | openssl x509 -text 2>&1 | egrep "Before|After")
	if [ "${RESULT}x" = "x" ]
	then
		echo "ERROR"
	else
		echo "${RESULT}"
	fi
}

echo "-- Process Check --"
check_proc slapd ldap
check_proc opendkim opendkim
check_proc dovecot dovecot
check_proc clamav-milter clamilt
check_proc clamd clamilt
check_proc yenma yenma
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
	check_dns ${HOST} A
	check_dns autoconfig.${x} A
	check_dns _dmarc.${x} TXT
	check_dns _adsp._domainkey.${x} TXT
	check_dns default._domainkey.${x} TXT
	echo
done

echo "-- ${FIRST_DOMAIN} TLS Check --"
check_cert ${x}

echo

echo "-- print_version --"
for x in os slapd opendkim dovecot clamav-milter clamd yenma postfix mysql php-fpm nginx roundcube phpldapadmin rainloop
do
	check_version ${x}
done
