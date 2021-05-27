#!/bin/bash -x
# @sacloud-name "zabbix-agent"
# @sacloud-once
# @sacloud-desc-begin
#   さくらのクラウド上で Zabbix Agent を 自動的にセットアップするスクリプトです
#   このスクリプトは、AlmaLinux 8.X でのみ動作します
# @sacloud-desc-end
# @sacloud-textarea heredoc ADDR "登録するZabbixサーバのIPアドレス(ipv4)を1行に1つ入力してください。" ex="127.0.0.1"
# @sacloud-require-archive distro-alma distro-ver-8.*

#---------UPDATE /etc/motd----------#
_motd() {
	log=$(ls /root/.sacloud-api/notes/*log)
	case $1 in
	start)
		echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the logfile: ${log}\n" > /etc/motd
	;;
	fail)
		echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the logfile: ${log}\n" > /etc/motd
	;;
	end)
		cp -f /dev/null /etc/motd
	;;
	esac
}

set -e
trap '_motd fail' ERR

_motd start

#---------SET sacloud values---------#
ZABBIX_VERSION=5.0
IPLIST=/tmp/ip.list
cat > ${IPLIST} @@@ADDR@@@

if [ $(grep -c "CentOS Stream release 8" /etc/redhat-release) -eq 1 ]
then
	sleep 30
fi
#---------START OF zabbix-agent---------#
RPM_URL=https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm
rpm -ivh ${RPM_URL}
dnf -y install zabbix-agent zabbix-sender

ZBX_SERVERS=127.0.0.1
for IPADDR in $(egrep "([0-9]+\.){3}[0-9]+$" ${IPLIST})
do
	ZBX_SERVERS="${ZBX_SERVERS},${IPADDR}"
	firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${IPADDR}/32' accept"
done

if [ $(egrep -c "([0-9]+\.){3}[0-9]+$" ${IPLIST}) -eq 0 ]
then
	firewall-cmd --permanent --add-port=10050/tcp
else
	sed -i "s/^Server=127.0.0.1$/Server=${ZBX_SERVERS}/" /etc/zabbix/zabbix_agentd.conf
fi

systemctl enable zabbix-agent
systemctl start zabbix-agent

rm -f ${IPLIST}

#---------END OF zabbix-agent---------#
#---------START OF firewalld---------#
firewall-cmd --reload
#---------END OF firewalld---------#

_motd end
