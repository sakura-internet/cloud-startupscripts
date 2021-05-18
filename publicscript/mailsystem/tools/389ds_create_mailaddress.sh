#!/bin/bash -e
#
# usage)
# ./389ds_create_mailaddress.sh <mailaddress>

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
basedn=""
for x in $(echo "${domain}" | sed 's/\./ /g')
do
	basedn="${basedn},dc=${x}"
done
basedn="ou=People${basedn}"

cat <<-_EOL_>${WORKDIR}/ldap/${domain}_${account}.ldif
dn: uid=${account},${basedn}
objectClass: mailRecipient
objectClass: top
uid: ${account}
userPassword: ${password}
mailMessageStore: ${STORE_SERVER}
mailHost: ${OUTBOUND_MTA_SERVER}
mailRoutingAddress: ${account}@${domain}
mailAlternateAddress: ${account}@${domain}

_EOL_
ldapadd -x -h ${LDAP_MASTER} -D "${ROOT_DN}" -w ${ROOT_PASSWORD} -f ${WORKDIR}/ldap/${domain}_${account}.ldif >/dev/null

echo ${password}
