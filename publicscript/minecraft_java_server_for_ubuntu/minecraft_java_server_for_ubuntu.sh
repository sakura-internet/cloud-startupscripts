#!/bin/bash

# @sacloud-name "Minecraft Java Server for Ubuntu"
# @sacloud-once
#
# @sacloud-desc-begin
#   Minecraft Server（Java版）をインストールします。
#   このスクリプトは、Ubuntu 18.04, 20.04 系でのみ動作します。
#
#   Minecraft Server（Java版）のご利用に当たり、
#   事前に以下URLの Minecraft使用許諾契約書 への承諾をお願いします。
#   https://account.mojang.com/documents/minecraft_eula
# @sacloud-desc-end
#
# @sacloud-require-archive distro-ubuntu distro-ver-18.04.*
# @sacloud-require-archive distro-ubuntu distro-ver-20.04.*

_motd() {
	log=$(ls /root/.sacloud-api/notes/*log)
	motsh=/etc/update-motd.d/99-startup
	status=/tmp/startup.status
	echo "#!/bin/bash" > ${motsh}
	echo "cat $status" >> ${motsh}
	chmod 755 ${motsh}
	case $1 in
	start)
		echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the logfile: ${log}\n" > ${status}
	;;
	fail)
		echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the logfile: ${log}\n" > ${status}
		exit 1
	;;
	end)
		rm -f ${motsh}
	;;
	esac
}

_motd start
set -x

# Open port 25565/tcp
if [ -e "/etc/network/if-pre-up.d/iptables" ]; then
    iptables -I INPUT -p tcp -m tcp --dport 25565 -j ACCEPT
    iptables-save >/etc/iptables/iptables.rules
else
    cat <<-'EOF' >/etc/network/if-pre-up.d/iptables
	#!/bin/sh
	iptables-restore < /etc/iptables/iptables.rules
	exit 0
	EOF
    chmod 755 /etc/network/if-pre-up.d/iptables

    mkdir /etc/iptables
    cat <<-'EOF' >/etc/iptables/iptables.rules
	*filter
	:INPUT ACCEPT [0:0]
	:FORWARD ACCEPT [0:0]
	:OUTPUT ACCEPT [0:0]
	-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	-A INPUT -p icmp -j ACCEPT
	-A INPUT -i lo -j ACCEPT
	-A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
	-A INPUT -m state --state NEW -m tcp -p tcp --dport 25565 -j ACCEPT
	-A INPUT -j REJECT --reject-with icmp-host-prohibited
	-A FORWARD -j REJECT --reject-with icmp-host-prohibited
	COMMIT
	EOF

    iptables-restore < /etc/iptables/iptables.rules
fi

export DEBIAN_FRONTEND=noninteractive

apt -y update || exit 1
apt -y install curl || exit 1
apt -y install jq || exit 1
# Install the Java for running Minecraft server
apt -y install openjdk-8-jre-headless || exit 1
# Install the Screen as a background task executor
apt -y install screen || exit 1

# Create daemon service
cat <<EOF >/etc/systemd/system/minecraft.service
[Unit]
Description=Server daemon for Minecraft
[Service]
Type=forking
User=ubuntu
KillMode=none
Restart=on-failure
ExecStart=/usr/bin/screen -dmS minecraft /bin/bash -c "/opt/minecraft/start_server.sh"
ExecStop=/usr/bin/screen -S minecraft -X stuff "stop\r"
[Install]
WantedBy=multi-user.target
EOF

# Create server directory
mkdir /opt/minecraft

# Generate a server start script
cat <<EOF >/opt/minecraft/start_server.sh
#!/bin/bash
/opt/minecraft/update_server.sh ; cd /opt/minecraft && java -Xms1024M -Xmx1024M -jar server.jar nogui
EOF
chmod +x /opt/minecraft/start_server.sh

# Generate a server update script
touch /opt/minecraft/.server_current
cat <<'EOF' >/opt/minecraft/update_server.sh
#!/bin/bash
cd /opt/minecraft
URL_SERVER_VERSION_MANIFEST=https://launchermeta.mojang.com/mc/game/version_manifest.json
MANIFEST=`curl $URL_SERVER_VERSION_MANIFEST`
LATEST_RELEASE=`echo $MANIFEST | jq -r '.latest.release'`
CURRENT_RELEASE=`cat .server_current`
if [ $LATEST_RELEASE != "$CURRENT_RELEASE" ]; then
  URL_ARGUMENTS=`echo $MANIFEST | jq -r ".versions | map(select(.id == \"${LATEST_RELEASE}\"))[0].url"`
  
  URL_SERVER_DL=`curl $URL_ARGUMENTS | jq -r "select(.id == \"${LATEST_RELEASE}\").downloads.server.url"`
  wget -q $URL_SERVER_DL -O server.jar
  echo $LATEST_RELEASE > .server_current
fi
EOF
chmod +x /opt/minecraft/update_server.sh

# Download server file
/opt/minecraft/update_server.sh

# Start server to generate eula file. This command will exit with non 0.
/opt/minecraft/start_server.sh

# Agree to the EULA
sed -i s/false/true/I /opt/minecraft/eula.txt

# Change owner to ubuntu for running server as ubuntu
chown -R ubuntu /opt/minecraft

# Start server with agreed EULA
systemctl start minecraft
# Set to start automatically at reboot
systemctl enable minecraft

_motd end