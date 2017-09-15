#!/bin/bash

BACKUP=/root/startup-script-mailsystem/backup
mkdir -p ${BACKUP}

GENERATION=7
BACKUP=${BACKUP}/backup.ldif

for x in $(seq 1 ${GENERATION} | sort -r)
do
	if [ -f "${BACKUP}.${x}.gz" ]
	then
		n=$((${x}+1))
		if [ ${n} -le ${GENERATION} ]
		then
			mv -f ${BACKUP}.${x}.gz ${BACKUP}.${n}.gz
		fi
	fi
done

slapcat 2>/dev/null > ${BACKUP}.tmp

if [ $? -eq 1 ]
then
	echo "backup ldif error"
	exit 1
fi

cat ${BACKUP}.tmp | egrep -v "structuralObjectClass|entryUUID|creatorsName|createTimestamp|entryCSN|modifiersName|modifyTimestamp" > ${BACKUP}

mv ${BACKUP} ${BACKUP}.1 && gzip ${BACKUP}.1
rm -f ${BACKUP}.tmp
