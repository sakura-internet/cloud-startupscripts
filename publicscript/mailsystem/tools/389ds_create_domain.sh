#!/bin/bash -e
#
# ./389ds_create_domain.sh <domain>

source $(dirname $0)/../config.source
echo "---- $0 ----"

mkdir -p ${WORKDIR}/ldap

if [ $# -ne 0 ]
then
  DOMAIN_LIST="$*"
fi

if [ ! -f "${WORKDIR}/ldap/config.ldif" ]
then
	cat <<-_EOL_>> ${WORKDIR}/ldap/config.ldif
	dn: cn=config
	changetype: modify
	replace: nsslapd-allow-hashed-passwords
	nsslapd-allow-hashed-passwords: on
	
	changetype: modify
	replace: nsslapd-sizelimit
	nsslapd-sizelimit: -1
	_EOL_
	ldapmodify -D ${ROOT_DN} -w ${ROOT_PASSWORD} -f ${WORKDIR}/ldap/config.ldif

	cat <<-_EOL_>> ${WORKDIR}/ldap/limit.ldif
	dn: cn=config,cn=ldbm database,cn=plugins,cn=config
	changetype: modify
	replace: nsslapd-lookthroughlimit
	nsslapd-lookthroughlimit: -1
	_EOL_
	ldapmodify -D ${ROOT_DN} -w ${ROOT_PASSWORD} -f ${WORKDIR}/ldap/limit.ldif
fi

for domain in ${DOMAIN_LIST}
do
	account=$(echo ${ADMINS} | awk '{print $1}')
	base=$(echo ${domain} | sed -e 's/\(^\|\.\)/,dc=/g' -e 's/^,//')
	dc=$(echo ${domain} | awk -F\. '{print $1}')
	if [ $(ldapsearch -h ${LDAP_MASTER} -x -D "${ROOT_DN}" -w ${ROOT_PASSWORD} -b "${base}" | grep -c ^dn:) -eq 0 ]
	then
		cat <<-_EOL_>>${WORKDIR}/ldap/${domain}.ldif
		dn: ${base}
		objectClass: dcObject
		objectClass: organization
		dc: ${dc}
		o: ${domain}
		
		_EOL_
	fi

	#-- create root
	count=1
	while :;
	do
		if [ $(dsconf localhost backend suffix list | fgrep -ci "(userroot${count})") -eq 0 ]
		then
			dsconf localhost backend create --suffix ${base} --be-name userRoot${count}
			break
		else
			count=$(expr ${count} + 1)
		fi
	done

	people="ou=People,${base}"
	termed=$(echo ${people} | sed 's/ou=People/ou=Termed/')

	cat <<-_EOL_>>${WORKDIR}/ldap/${domain}.ldif
	dn: ${people}
	ou: People
	objectclass: organizationalUnit

	dn: ${termed}
	ou: Termed
	objectclass: organizationalUnit
	
	dn: uid=${account},${people}
	objectClass: mailRecipient
	objectClass: top
	userPassword: ${ROOT_PASSWORD}
	mailMessageStore: ${STORE_SERVER}
	mailHost: ${OUTBOUND_MTA_SERVER}
	mailAccessDomain: ${domain}
	mailRoutingAddress: ${account}@${domain}
	mailAlternateAddress: ${account}@${domain}
	_EOL_

	for alt in ${ADMINS}
	do
		if [ "${alt}" = "${account}" ]
		then
			continue
		fi
		echo "mailAlternateAddress: ${alt}@${domain}" >> ${WORKDIR}/ldap/${domain}.ldif
	done

	echo >> ${WORKDIR}/ldap/${domain}.ldif
	ldapadd -x -h ${LDAP_MASTER} -D "${ROOT_DN}" -w ${ROOT_PASSWORD} -f ${WORKDIR}/ldap/${domain}.ldif
	mv -f ${WORKDIR}/ldap/${domain}.ldif ${WORKDIR}/ldap/${domain}_admin.ldif
	echo "${account}@${domain}: ${ROOT_PASSWORD}" >> ${WORKDIR}/password.list

	#-- acl
	echo "dn: ${base}" > ${WORKDIR}/ldap/${domain}_acl.ldif
	cat <<-'_EOL_'>> ${WORKDIR}/ldap/${domain}_acl.ldif
	changeType: modify
	replace: aci
	aci: (targetattr="UserPassword")(target!="ldap:///uid=*,ou=Termed,dc=*")(version 3.0; acl "1"; allow(write) userdn="ldap:///self";)
	aci: (targetattr="*")(target!="ldap:///uid=*,ou=Termed,dc=*")(version 3.0; acl "5"; allow(read) userdn="ldap:///self";)
	aci: (targetattr="UserPassword")(target!="ldap:///uid=*,ou=Termed,dc=*")(version 3.0; acl "2"; allow(compare) userdn="ldap:///anyone";)
	aci: (targetattr!="UserPassword")(target!="ldap:///uid=*,ou=Termed,dc=*")(version 3.0; acl "3"; allow(search,read) userdn="ldap:///anyone";)
	_EOL_
	ldapmodify -D ${ROOT_DN} -w ${ROOT_PASSWORD} -f ${WORKDIR}/ldap/${domain}_acl.ldif

done

