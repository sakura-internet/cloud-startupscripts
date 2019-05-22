#!/bin/bash -e
#
# usage)
# ./create_mailaddress.sh <mailaddress>

address=$1
source $(dirname $0)/../config.source

ldapsearch -x -h ${LDAP_MASTER} -D "${ROOT_DN}" -w ${ROOT_PASSWORD} > /dev/null 2>&1

if [ $? -ne 0 ]
then
	echo "invalid rootdn or rootpassword!!"
	exit 1
fi

if [ $(ldapsearch -x mailRoutingAddress=${address} | grep -c "^mailRoutingAddress") -ne 0 ]
then
	echo "${address} is already exist!!"
	exit 1
fi

mkdir -p ${WORKDIR}/ldap

account=$(echo ${address} | awk -F@ '{print $1}')
if [ $(echo "${ADMINS}" | grep -c " ${account} ") -eq 1 ]
then
	echo "skip ${address}"
	continue
fi
domain=$(echo ${address} | awk -F@ '{print $2}')
password=$(mkpasswd -l 12 -d 3 -c 3 -C 3 -s 0)
sshapw=$(slappasswd -s ${password})
basedn=""
for x in $(echo "${domain}" | sed 's/\./ /g')
do
	basedn="${basedn},dc=${x}"
done
basedn="ou=People${basedn}"

cat <<-_EOL_>>${WORKDIR}/ldap/${domain}_${account}.ldif
dn: uid=${account},${basedn}
objectclass: uidObject
objectClass: simpleSecurityObject
objectclass: inetLocalMailRecipient
objectClass: sendmailMTA
uid: ${account}
userPassword: ${sshapw}
mailHost: ${STORE_SERVER}
sendmailMTAHost: ${OUTBOUND_MTA_SERVER}
mailRoutingAddress: ${account}@${domain}
mailLocalAddress: ${account}@${domain}

_EOL_
ldapadd -x -h ${LDAP_MASTER} -D "${ROOT_DN}" -w ${ROOT_PASSWORD} -f ${WORKDIR}/ldap/${domain}_${account}.ldif >/dev/null

# アーカイブ
if [ "${account}" = "archive" ]
then

	# 送信アーカイブ設定
	echo "/^(.*)@${domain}\$/    archive+\$1-Sent@${domain}" >> /etc/postfix/sender_bcc_maps
	postconf -c /etc/postfix -e sender_bcc_maps=regexp:/etc/postfix/sender_bcc_maps

	# 受信アーカイブ設定
	if [ ! -f /etc/postfix/recipient_bcc_maps ]
	then
		cat <<-_EOL_>/etc/postfix-inbound/recipient_bcc_maps
		if !/^archive\+/
		/^(.*)@${domain}\$/  archive+\$1-Recv@${domain}
		endif
		_EOL_
	else
		sed -i "2i /^(.*)@${domain}\$/  archive+\$1-Recv@${domain}" /etc/postfix/recipient_bcc_maps
	fi
	postconf -c /etc/postfix-inbound -e recipient_bcc_maps=regexp:/etc/postfix-inbound/recipient_bcc_maps

	# １年経過したアーカイブメールを削除
	echo "0 $((${RANDOM}%6+1)) * * * root doveadm expunge -u archive@${domain} mailbox \* before 365d" >> ${CRONFILE}
fi

echo ${password}

