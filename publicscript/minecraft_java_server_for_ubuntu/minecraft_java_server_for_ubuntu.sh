#!/bin/bash

# @sacloud-name "Minecraft Java Server for Ubuntu"
# @sacloud-once
#
# @sacloud-desc-begin
#   Minecraft Server（Java版）をインストールします。
#   このスクリプトは、Ubuntu 18.04, 20.04 系でのみ動作します。
#
#   Minecraft Server（Java版）のご利用に当たり、
#   事前に以下URLの Minecraft使用許諾契約書 (EULA) への承諾をお願いします。
#   https://account.mojang.com/documents/minecraft_eula
# @sacloud-desc-end
#
# @sacloud-checkbox required EULA_ACCEPTED "Minecraft使用許諾契約 (EULA) に同意して利用する"
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
set -eux

: "pre check" && {
    : "EULA" && {
        if [[ -z '@@@EULA_ACCEPTED@@@' ]]; then
            echo "You must agree to the EULA" >&2
            exit 1
        fi
    }
}

# Open port 25565
ufw allow 22
ufw allow 25565
ufw enable

export DEBIAN_FRONTEND=noninteractive

apt -y update
apt -y install curl
apt -y install jq
# Install the Java for running Minecraft server
apt -y install openjdk-8-jre-headless
# Install the Screen as a background task executor
apt -y install screen

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
