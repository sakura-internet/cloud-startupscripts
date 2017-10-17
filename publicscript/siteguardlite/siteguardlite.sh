#!/bin/bash
# @sacloud-once
# @sacloud-desc 完了後自動再起動します。
# @sacloud-desc （このスクリプトは、CentOS6.X, 7.Xでのみ動作します）
# @sacloud-desc セットアップ完了後、ご利用ガイド、管理者用ガイド5.1～を参照し初期設定を実施してください。
# @sacloud-require-archive distro-centos distro-ver-6.*
# @sacloud-require-archive distro-centos distro-ver-7.*
## ScriptName : CentOS_SiteGuardLite-Apache
set -x

function centos6(){
	iptables -S INPUT | grep -q "\-\-dport 80 \-j ACCEPT"
	[ "$?" = "0" ] ||  iptables -I INPUT 5 -p tcp -m tcp --dport 80 -j ACCEPT
	iptables -S INPUT | grep -q "\-\-dport 443 \-j ACCEPT"
	[ "$?" = "0" ] ||  iptables -I INPUT 5 -p tcp -m tcp --dport 443 -j ACCEPT
	iptables -S INPUT | grep -q "\-\-dport 9443 \-j ACCEPT"
	[ "$?" = "0" ] ||  iptables -I INPUT 5 -p tcp -m tcp --dport 9443 -j ACCEPT
	iptables-save > /etc/sysconfig/iptables

	rm -fr /var/cache/yum/*
	yum clean all
	yum install -y httpd glibc perl wget unzip openssl make file java mod_ssl
	wget -q http://progeny.sakura.ad.jp/siteguard/3.3.0/apache/siteguardlite-3.30-0.apache.x86_64.rpm -P /root/.sakuravps
	rpm -Uvh /root/.sakuravps/siteguardlite-3.30-0.apache.x86_64.rpm

	chkconfig httpd on || exit 1

	cat > /opt/jp-secure/siteguardlite/conf/dbupdate_waf_url.conf <<-EOF
	LATEST_URL=https://www.jp-secure.com/download/siteguardlite_sp/updates_lite/latest-lite.zip
	EOF

	cd /opt/jp-secure/siteguardlite/
	yes '' | ./setup.sh || exit 1
}


function centos7(){
	STATE_HTTP=$(firewall-cmd --query-service=http)
	[ "$STATE_HTTP" = "yes" ] ||  firewall-cmd --add-service=http --zone=public --permanent
	STATE_HTTPS=$(firewall-cmd --query-service=https)
	[ "$STATE_HTTPS" = "yes" ] ||  firewall-cmd --add-service=https --zone=public --permanent
	STATE_9443=$(firewall-cmd --query-port=9443/tcp)
	[ "$STATE_9443" = "yes" ] || firewall-cmd --add-port=9443/tcp --zone=public --permanent
	firewall-cmd --reload

	rm -fr /var/cache/yum/*
	yum clean all
	yum install -y httpd glibc perl wget unzip openssl make file java mod_ssl
	wget -q http://progeny.sakura.ad.jp/siteguard/3.3.0/apache/siteguardlite-3.30-0.apache.x86_64.rpm -P /root/.sakuravps
	rpm -Uvh /root/.sakuravps/siteguardlite-3.30-0.apache.x86_64.rpm

	systemctl enable httpd.service || exit 1

	cat > /opt/jp-secure/siteguardlite/conf/dbupdate_waf_url.conf <<-EOF
	LATEST_URL=https://www.jp-secure.com/download/siteguardlite_sp/updates_lite/latest-lite.zip
	EOF

	cd /opt/jp-secure/siteguardlite/
	yes '' | ./setup.sh || exit 1
}

### main ###
VERSION=$(rpm -q centos-release --qf "%{VERSION}")

[ "$VERSION" = "6" ] && centos6
[ "$VERSION" = "7" ] && centos7

sh -c "echo -e '##########\nReboot after 10 seconds\n##########' | wall -n; sleep 10; reboot" &
exit 0
