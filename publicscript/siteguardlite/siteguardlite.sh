#!/bin/bash
# @sacloud-name "SiteGuard Server Edition for CentOS"
# @sacloud-once
# @sacloud-desc WAF(Web Application Firewall)は、これまでのL3ファイアウォールでは防御することが難しかった、Web上で動作するアプリケーションなどのL7への攻撃検知・防御や、アクセス制御機構などを提供するものです。
# @sacloud-desc さくらのクラウドではJP-Secure社が開発する純国産のホスト型WAF製品「SiteGuard Server Edition」をさくらのクラウド向け特別版として無料で提供しています。
# @sacloud-desc 完了後自動再起動します。
# @sacloud-desc （このスクリプトは、CentOS6.X, 7.Xでのみ動作します）
# @sacloud-desc セットアップ完了後、ご利用ガイド、管理者用ガイド5.1～を参照し初期設定を実施してください。
# @sacloud-require-archive distro-centos distro-ver-6.*
# @sacloud-require-archive distro-centos distro-ver-7.*
## ScriptName : CentOS_SiteGuardServerEdition-Apache
#===== Startup Script Motd Monitor =====#
_motd() {
	LOG=$(ls /root/.sacloud-api/notes/*log)
	case $1 in
		start)
			echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
		;;
		fail)
			echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
		exit 1
		;;
		end)
			cp -f /dev/null /etc/motd
		;;
	esac
}


function centos6(){
	trap '_motd fail' ERR
	yum install -y httpd glibc perl wget unzip openssl make file java mod_ssl expect
	wget -q http://progeny.sakura.ad.jp/siteguard/4.0.0/apache/siteguard-server-edition-4.00-2.apache.x86_64.rpm -P /root/.sakuracloud
	rpm -Uvh /root/.sakuracloud/siteguard-server-edition-4.00-2.apache.x86_64.rpm

	chkconfig httpd on

	cat > /opt/jp-secure/siteguardlite/conf/dbupdate_waf_url.conf <<-EOF
	LATEST_URL=https://www.jp-secure.com/download/siteguardlite_sp/updates_lite/latest-lite.zip
	EOF

	cd /opt/jp-secure/siteguardlite/
	expect -c "
		spawn ./setup.sh
		set i 0
		while {\$i <= 32} {
			expect -- \"-->\"
			send -- \"\n\"
			incr i 1
		}
	"
}


function centos7(){
	trap '_motd fail' ERR
	firewall-cmd --add-service=http --zone=public --permanent
	firewall-cmd --add-service=https --zone=public --permanent
	firewall-cmd --add-port=9443/tcp --zone=public --permanent
	firewall-cmd --reload

	yum install -y httpd glibc perl wget unzip openssl make file java mod_ssl expect
	wget -q http://progeny.sakura.ad.jp/siteguard/4.0.0/apache/siteguard-server-edition-4.00-2.apache.x86_64.rpm -P /root/.sakuracloud
	rpm -Uvh /root/.sakuracloud/siteguard-server-edition-4.00-2.apache.x86_64.rpm

	systemctl enable httpd.service

	cat > /opt/jp-secure/siteguardlite/conf/dbupdate_waf_url.conf <<-EOF
	LATEST_URL=https://www.jp-secure.com/download/siteguardlite_sp/updates_lite/latest-lite.zip
	EOF

	cd /opt/jp-secure/siteguardlite/
	expect -c "
		spawn ./setup.sh
		set i 0
		while {\$i <= 32} {
			expect -- \"-->\"
			send -- \"\n\"
			incr i 1
		}
	"
}

### main ###
_motd start
set -ex

VERSION=$(rpm -q centos-release --qf "%{VERSION}")

[ "$VERSION" = "6" ] && centos6
[ "$VERSION" = "7" ] && centos7

_motd end
sh -c "echo -e '##########\nReboot after 10 seconds\n##########' | wall -n; sleep 10; reboot" &

exit 0
