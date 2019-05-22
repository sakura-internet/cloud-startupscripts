#!/bin/bash -e
#
# ./create_domain.sh <domain>

source $(dirname $0)/../config.source
echo "---- $0 ----"

ldapsearch -x -h ${LDAP_MASTER} -D "${ROOT_DN}" -w ${ROOT_PASSWORD} > /dev/null 2>&1

if [ $? -ne 0 ]
then
	echo "invalid rootdn or rootpassword!!"
	exit 1
fi

mkdir -p ${WORKDIR}/ldap

if [ $# -ne 0 ]
then
  DOMAIN_LIST="$*"
fi

for domain in ${DOMAIN_LIST}
do
	account=$(echo ${ADMINS} | awk '{print $1}')
	sshapw=$(slappasswd -s ${ROOT_PASSWORD})
	tmpdn=""
	for x in $(for y in $(echo "${domain}" | sed 's/\./ /g')
	do
		echo ${y}
	done | tac) 
	do
		tmpdn="dc=${x}${tmpdn}"
		if [ $(ldapsearch -h ${LDAP_MASTER} -x -D "${ROOT_DN}" -w ${ROOT_PASSWORD} -b "${tmpdn}" | grep -c ^dn:) -eq 0 ]
		then
			cat <<-_EOL_>>${WORKDIR}/ldap/${domain}.ldif
			dn: ${tmpdn}
			objectClass: dcObject
			objectClass: organization
			dc: ${x}
			o: ${domain}

			_EOL_
		fi
		tmpdn=",${tmpdn}"
	done
	BASEDN=$(echo ${tmpdn} | sed 's/^,//')
	BASEDN="ou=People,${BASEDN}"
	DISABLE=$(echo ${BASEDN} | sed 's/ou=People/ou=Termed/')

	cat <<-_EOL_>>${WORKDIR}/ldap/${domain}.ldif
	dn: ${BASEDN}
	ou: People
	objectclass: organizationalUnit

	dn: ${DISABLE}
	ou: Disable
	objectclass: organizationalUnit
	
	dn: uid=${account},${BASEDN}
	objectclass: uidObject
	objectClass: simpleSecurityObject
	objectClass: inetLocalMailRecipient
	objectClass: sendmailMTA
	uid: ${account}
	userPassword: ${sshapw}
	mailHost: ${STORE_SERVER}
	sendmailMTAHost: ${OUTBOUND_MTA_SERVER}
	mailRoutingAddress: ${account}@${domain}
	mailLocalAddress: ${account}@${domain}
	_EOL_

	for z in ${ADMINS}
	do
		if [ "${z}" = "${account}" ]
		then
			continue
		fi
		echo "mailLocalAddress: ${z}@${domain}" >> ${WORKDIR}/ldap/${domain}.ldif
	done

	echo >> ${WORKDIR}/ldap/${domain}.ldif
	ldapadd -x -h ${LDAP_MASTER} -D "${ROOT_DN}" -w ${ROOT_PASSWORD} -f ${WORKDIR}/ldap/${domain}.ldif
	mv -f ${WORKDIR}/ldap/${domain}.ldif ${WORKDIR}/ldap/${domain}_admin.ldif

	echo "${account}@${domain}: ${ROOT_PASSWORD}" >> ${WORKDIR}/password.list
done

