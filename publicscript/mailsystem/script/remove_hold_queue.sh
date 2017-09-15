#!/bin/bash
#
# holdしているウィルスメールを削除してレポートするスクリプト

TMP=/tmp/virusscan.tmp
FROM=virus-report@_DOMAIN_

export PATH=${PATH}:/usr/sbin:/sbin

for x in $(find /var/spool/postfix*/hold -type f)
do
	QID=$(basename ${x})
	postcat -bh ${x} | clamdscan -c /etc/clamd.d/scan.conf - > ${TMP} 2>&1
	if [ $(grep -c "^Infected files: [1-9]" ${TMP}) -eq 1 ]
	then
		VIRUS=$(grep "^stream:" ${TMP} | sed 's/stream: //')
		if [ $(echo ${x} | grep -c "postfix-inbound") -eq 1 ]
		then
			### 宛先にウィルスメールを削除した報告
			SENDER=$(postcat -e ${x} | grep -v ' archive+' | awk '/^sender:/{print $2}')
			RCPT=$(postcat -e ${x} | grep -v ' archive+' | awk '/^recipient:/{print $2}')
			TO=${RCPT}
		else
			### 送信元にウィルスメールを削除した報告
			SENDER=$(postcat -e ${x} | grep -v ' archive+' | awk '/^sender:/{print $2}')
			RCPT=$(postcat -e ${x} | grep -v ' archive+' | awk '/^recipient:/{print $2}')
			TO=${SENDER}
		fi
		echo -e "Subject: System Report) Remove Virus Mail\nTo: ${TO}\n\nsender: ${SENDER}\nrecipient: ${RCPT}\nstream: ${VIRUS}" | sendmail -f ${FROM} ${TO}
		MULTINAME=$(basename $(echo $(dirname $(echo $(dirname $(echo ${x}))))))

		### hold しているウィルスメールキューを削除
		postsuper -c /etc/${MULTINAME} -d ${QID}
	fi
done

rm -f /tmp/virusscan.tmp

exit 0
