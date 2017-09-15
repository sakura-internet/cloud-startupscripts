#!/bin/bash -x
# usage)
# ./create_mailaddress.sh <mailaddress>

set -e

ADDRESS=$1

source $(dirname $0)/../config.source

ldapsearch -x -h ${LDAP_MASTER} -D "${ROOT_DN}" -w ${ROOT_PASSWORD} > /dev/null 2>&1

if [ $? -ne 0 ]
then
	echo "invalid rootdn or rootpassword!!"
	exit 1
fi

if [ $(ldapsearch -x mailRoutingAddress=${ADDRESS} | grep -c "^mailRoutingAddress") -ne 0 ]
then
	echo "${ADDRESS} is already exist!!"
	exit 1
fi

mkdir -p ${WORKDIR}/ldap

ACCOUNT=$(echo ${ADDRESS} | awk -F@ '{print $1}')
if [ $(echo "${ADMINS}" | grep -c " ${ACCOUNT} ") -eq 1 ]
then
	echo "skip ${ADDRESS}"
	continue
fi
DOMAIN=$(echo ${ADDRESS} | awk -F@ '{print $2}')
#PASSWORD="${ACCOUNT}!"
PASSWORD=$(mkpasswd -l 12 -d 3 -c 3 -C 3 -s 0)
SSHAPW=$(slappasswd -s ${PASSWORD})
BASEDN=""
for x in $(echo "${DOMAIN}" | sed 's/\./ /g')
do
	BASEDN="${BASEDN},dc=${x}"
done
BASEDN="ou=People${BASEDN}"

cat <<-_EOL_>>${WORKDIR}/ldap/${DOMAIN}_${ACCOUNT}.ldif
dn: uid=${ACCOUNT},${BASEDN}
objectclass: uidObject
objectClass: simpleSecurityObject
objectclass: inetLocalMailRecipient
objectClass: sendmailMTA
uid: ${ACCOUNT}
userPassword: ${SSHAPW}
mailHost: ${STORE_SERVER}
sendmailMTAHost: ${OUTBOUND_MTA_SERVER}
mailRoutingAddress: ${ACCOUNT}@${DOMAIN}
mailLocalAddress: ${ACCOUNT}@${DOMAIN}

_EOL_
ldapadd -x -h ${LDAP_MASTER} -D "${ROOT_DN}" -w ${ROOT_PASSWORD} -f ${WORKDIR}/ldap/${DOMAIN}_${ACCOUNT}.ldif >/dev/null

# アーカイブ
if [ "${ACCOUNT}" = "archive" ]
then

	# 送信アーカイブ設定
	echo "/^(.*)@${DOMAIN}\$/    archive+\$1-Sent@${DOMAIN}" >> /etc/postfix/sender_bcc_maps
	postconf -c /etc/postfix -e sender_bcc_maps=regexp:/etc/postfix/sender_bcc_maps

	# 受信アーカイブ設定
	if [ ! -f /etc/postfix/recipient_bcc_maps ]
	then
		cat <<-_EOL_>/etc/postfix/recipient_bcc_maps
		if !/^archive\+/
		/^(.*)@${DOMAIN}\$/  archive+\$1-Recv@${DOMAIN}
		endif
		_EOL_
	else
		sed -i "2i /^(.*)@${DOMAIN}\$/  archive+\$1-Recv@${DOMAIN}" /etc/postfix/recipient_bcc_maps
	fi

	# １年経過したアーカイブメールを削除
	echo "0 $((${RANDOM}%6+1)) * * * root /usr/local/dovecot/bin/doveadm expunge -u archive@${DOMAIN} mailbox \* before 365d" >> /etc/cron.d/startup-script-cron
fi

echo ${PASSWORD}

