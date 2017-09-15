#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

ldapsearch -x -h ${LDAP_MASTER} -D "${ROOT_DN}" -w ${ROOT_PASSWORD} > /dev/null 2>&1

if [ $? -ne 0 ]
then
	echo "invalid rootdn or rootpassword!!"
	exit 1
fi

mkdir -p ${WORKDIR}/ldap

for DOMAIN in ${DOMAIN_LIST}
do
	ACCOUNT=$(echo ${ADMINS} | awk '{print $1}')
	SSHAPW=$(slappasswd -s ${ROOT_PASSWORD})
	TMPDN=""
	for x in $(for y in $(echo "${DOMAIN}" | sed 's/\./ /g')
	do
		echo ${y}
	done | tac) 
	do
		TMPDN="dc=${x}${TMPDN}"
		if [ $(ldapsearch -h ${LDAP_MASTER} -x -D "${ROOT_DN}" -w ${ROOT_PASSWORD} -b "${TMPDN}" | grep -c ^dn:) -eq 0 ]
		then
			cat <<-_EOL_>>${WORKDIR}/ldap/${DOMAIN}.ldif
			dn: ${TMPDN}
			objectClass: dcObject
			objectClass: organization
			dc: ${x}
			o: ${DOMAIN}

			_EOL_
		fi
		TMPDN=",${TMPDN}"
	done
	BASEDN=$(echo ${TMPDN} | sed 's/^,//')
	BASEDN="ou=People,${BASEDN}"
	DISABLE=$(echo ${BASEDN} | sed 's/ou=People/ou=Disable/')

	cat <<-_EOL_>>${WORKDIR}/ldap/${DOMAIN}.ldif
	dn: ${BASEDN}
	ou: People
	objectclass: organizationalUnit

	dn: ${DISABLE}
	ou: Disable
	objectclass: organizationalUnit
	
	dn: uid=${ACCOUNT},${BASEDN}
	objectclass: uidObject
	objectClass: simpleSecurityObject
	objectClass: inetLocalMailRecipient
	objectClass: sendmailMTA
	uid: ${ACCOUNT}
	userPassword: ${SSHAPW}
	mailHost: ${STORE_SERVER}
	sendmailMTAHost: ${OUTBOUND_MTA_SERVER}
	description: ${DOMAIN}
	mailRoutingAddress: ${ACCOUNT}@${DOMAIN}
	mailLocalAddress: ${ACCOUNT}@${DOMAIN}
	_EOL_

	for z in ${ADMINS}
	do
		if [ "${z}" = "${ACCOUNT}" ]
		then
			continue
		fi
		echo "mailLocalAddress: ${z}@${DOMAIN}" >> ${WORKDIR}/ldap/${DOMAIN}.ldif
	done
	echo >> ${WORKDIR}/ldap/${DOMAIN}.ldif
	ldapadd -x -h ${LDAP_MASTER} -D "${ROOT_DN}" -w ${ROOT_PASSWORD} -f ${WORKDIR}/ldap/${DOMAIN}.ldif
	mv -f ${WORKDIR}/ldap/${DOMAIN}.ldif ${WORKDIR}/ldap/${DOMAIN}_admin.ldif
done

