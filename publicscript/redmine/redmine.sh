#!/bin/bash
# @sacloud-name "Redmine"
# @sacloud-once
# @sacloud-desc Redmineをインストールします。
# @sacloud-desc サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
# @sacloud-desc http://サーバのIPアドレス/
# @sacloud-desc ※ セットアップには20分程度時間がかかります。
<<<<<<< HEAD
# @sacloud-desc （このスクリプトは、CentOS6.X と CetnOS7.X で動作します）
# @sacloud-require-archive distro-centos distro-ver-6.*
# @sacloud-require-archive distro-centos distro-ver-7.*

function _motd() {
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

set -ex

function centos6(){
	_motd start
	trap '_motd fail' ERR

	cat <<-'EOT' > /etc/sysconfig/iptables
	*filter
	:INPUT DROP [0:0]
	:FORWARD DROP [0:0]
	:OUTPUT ACCEPT [0:0]
	:fail2ban-SSH - [0:0]
	-A INPUT -p tcp -m multiport --dports 22 -j fail2ban-SSH
	-A INPUT -p TCP -m state --state NEW ! --syn -j DROP
	-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	-A INPUT -p icmp -j ACCEPT
	-A INPUT -i lo -j ACCEPT
	-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
	-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
	-A INPUT -p udp --sport 123 --dport 123 -j ACCEPT
	-A INPUT -p udp --sport 53 -j ACCEPT
	-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
	-A fail2ban-SSH -j RETURN
	COMMIT
	EOT
	service iptables restart

	gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
	if [ "$?" != "0" ] ; then
		command curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
		command curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import -
	fi

	echo 'gem: --no-rdoc --no-ri' > /etc/gemrc

	yum clean all
	yum -y install readline-devel zlib-devel libyaml-devel libyaml openssl-devel libxml2-devel libxslt libxslt-devel libcurl-devel sqlite-devel
	curl -L https://get.rvm.io | bash -s stable --ignore-dotfiles --autolibs=0
	set +e
	source /usr/local/rvm/scripts/rvm
	set -e
	rvm install ${RUBY}
	rvm use ${RUBY}
	gem install rails --no-ri --no-rdoc

	yum -y install expect httpd-devel mod_ssl mysql-server
	service httpd status >/dev/null 2>&1 || service httpd start
	chkconfig httpd on

	service mysqld status >/dev/null 2>&1 || service mysqld start
	chkconfig mysqld on

        if [ ! -f /root/.my.cnf ] ;then
		NEWMYSQLPASSWORD=$(mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2)

		/usr/bin/mysqladmin -u root password "$NEWMYSQLPASSWORD"

		cat <<- EOT > /root/.my.cnf
		[client]
		host     = localhost
		user     = root
		password = $NEWMYSQLPASSWORD
		socket   = /var/lib/mysql/mysql.sock
		EOT
		chmod 600 /root/.my.cnf
	fi

	cat <<- EOT > /etc/my.cnf
	[mysqld]
	datadir=/var/lib/mysql
	socket=/var/lib/mysql/mysql.sock
	user=mysql
	# Disabling symbolic-links is recommended to prevent assorted security risks
	symbolic-links=0
	innodb_file_per_table
	query-cache-size=16M
	character-set-server=utf8
	[mysqld_safe]
	log-error=/var/log/mysqld.log
	pid-file=/var/run/mysqld/mysqld.pid
	[mysql]
	default-character-set=utf8
	EOT

	service mysqld restart

	yum -y install mysql-devel
	rpm -ivh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
	yum install --enablerepo=remi -y ImageMagick6 ImageMagick6-devel

	USERNAME="rm_$(mkpasswd -l 10 -C 0 -s 0)"
	PASSWORD=$(mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2)

	echo "create database db_redmine default character set utf8;" | mysql --defaults-file=/root/.my.cnf
	echo "grant all on db_redmine.* to $USERNAME@'localhost' identified by '$PASSWORD';" | mysql --defaults-file=/root/.my.cnf
	echo "flush privileges;" | mysql --defaults-file=/root/.my.cnf

	svn co http://svn.redmine.org/redmine/branches/${REDMINE} /var/lib/redmine

	cat <<- EOT > /var/lib/redmine/config/database.yml
	production:
	  adapter: mysql2
	  database: db_redmine
	  host: localhost
	  username: $USERNAME
	  password: $PASSWORD
	  encoding: utf8
	EOT

	cd /var/lib/redmine
	gem install json
	bundle install --without development test
	bundle exec rake generate_secret_token
	RAILS_ENV=production bundle exec rake db:migrate

	gem install passenger
	passenger-install-apache2-module -a
	passenger-install-apache2-module --snippet > /etc/httpd/conf.d/passenger.conf
	chown -R apache:apache /var/lib/redmine
	echo 'DocumentRoot "/var/lib/redmine/public"' > /etc/httpd/conf/redmine.conf
	echo "Include conf/redmine.conf" >> /etc/httpd/conf/httpd.conf
	service httpd restart

	_motd end
	set +e

}

function centos7(){
	_motd start
	trap '_motd fail' ERR

	firewall-cmd --add-service=http --zone=public --permanent
	firewall-cmd --add-service=https --zone=public --permanent
	firewall-cmd --reload

	gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
	if [ "$?" != "0" ] ; then
		command curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
		command curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import -
	fi

	echo 'gem: --no-rdoc --no-ri' > /etc/gemrc

	yum clean all
	yum -y install readline-devel zlib-devel libyaml-devel libyaml openssl-devel libxml2-devel libxslt libxslt-devel libcurl-devel sqlite-devel
	curl -L https://get.rvm.io | bash -s stable --ignore-dotfiles --autolibs=0
	set +e
	source /usr/local/rvm/scripts/rvm
	set -e
	rvm install ${RUBY}
	rvm use ${RUBY}
	gem install rails --no-ri --no-rdoc
	yum -y install expect httpd-devel mod_ssl mariadb-server
	yum -y install mariadb-devel ImageMagick-devel

	cat <<- EOT > /etc/my.cnf
	[mysqld]
	datadir=/var/lib/mysql
	socket=/var/lib/mysql/mysql.sock
	user=mysql
	# Disabling symbolic-links is recommended to prevent assorted security risks
	symbolic-links=0
	innodb_file_per_table
	query-cache-size=16M
	character-set-server=utf8
	[mysql]
	default-character-set=utf8
	EOT

	systemctl status mariadb.service >/dev/null 2>&1 || systemctl start mariadb.service
	systemctl enable mariadb.service

        if [ ! -f /root/.my.cnf ] ;then
		NEWMYSQLPASSWORD=$(mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2)
		/usr/bin/mysqladmin -u root password "$NEWMYSQLPASSWORD"

		cat <<- EOT > /root/.my.cnf
		[client]
		host     = localhost
		user     = root
		password = $NEWMYSQLPASSWORD
		socket   = /var/lib/mysql/mysql.sock
		EOT
		chmod 600 /root/.my.cnf
	fi

	USERNAME="rm_$(mkpasswd -l 10 -C 0 -s 0)"
	PASSWORD=$(mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2)

	echo "create database db_redmine default character set utf8;" | mysql --defaults-file=/root/.my.cnf
	echo "grant all on db_redmine.* to $USERNAME@'localhost' identified by '$PASSWORD';" | mysql --defaults-file=/root/.my.cnf
	echo "flush privileges;" | mysql --defaults-file=/root/.my.cnf

	svn co http://svn.redmine.org/redmine/branches/${REDMINE} /var/lib/redmine

	cat <<- EOT > /var/lib/redmine/config/database.yml
	production:
	  adapter: mysql2
	  database: db_redmine
	  host: localhost
	  username: $USERNAME
	  password: $PASSWORD
	  encoding: utf8
	EOT

	cd /var/lib/redmine
	gem install json
	bundle install --without development test
	bundle exec rake generate_secret_token
	RAILS_ENV=production bundle exec rake db:migrate

	cat <<- EOF > /etc/httpd/conf/redmine.conf
	DocumentRoot "/var/lib/redmine/public"
	<Directory "/var/lib/redmine/public">
	  Require all granted
	</Directory>
	EOF

	gem install passenger --no-rdoc --no-ri
	passenger-install-apache2-module -a
	passenger-install-apache2-module --snippet > /etc/httpd/conf.d/passenger.conf
	chown -R apache:apache /var/lib/redmine
	echo "Include conf/redmine.conf" >> /etc/httpd/conf/httpd.conf

	systemctl status httpd.service >/dev/null 2>&1 || systemctl start httpd.service
	systemctl enable httpd.service

	_motd end
	set +e

}

### main ###

VERSION=$(rpm -q centos-release --qf "%{VERSION}")
RUBY=ruby-2.5.5
REDMINE=4.0-stable

[ "$VERSION" = "6" ] && centos6
[ "$VERSION" = "7" ] && centos7

shutdown -r 1
=======
# @sacloud-desc （このスクリプトは、CentOS6.Xでのみ動作します）
# @sacloud-require-archive distro-centos distro-ver-6.*

#---------START OF iptables---------#
cat <<'EOT' > /etc/sysconfig/iptables
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:fail2ban-SSH - [0:0]
-A INPUT -p tcp -m multiport --dports 22 -j fail2ban-SSH
-A INPUT -p TCP -m state --state NEW ! --syn -j DROP
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
-A INPUT -p udp --sport 123 --dport 123 -j ACCEPT
-A INPUT -p udp --sport 53 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
-A fail2ban-SSH -j RETURN
COMMIT
EOT
service iptables restart
#---------END OF iptables---------#
#---------START OF Rails---------#
gpg2 --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB || exit 1
echo -e "install: --no-document\nupdate:  --no-document" > /root/.gemrc
yum -y install readline-devel zlib-devel curl-devel libyaml-devel libyaml openssl-devel libxml2-devel libxslt libxslt-devel curl-devel sqlite-devel || exit 1
curl -L https://get.rvm.io | bash -s stable --ignore-dotfiles --autolibs=0 || exit 1
source /usr/local/rvm/scripts/rvm || exit 1
rvm install ruby-2.4.5 || exit 1
rvm use ruby-2.4.5 || exit 1
gem install rails --no-document || exit 1
#---------END OF Rails---------#
#---------START OF Apache & MySQL---------#
yum -y install expect httpd-devel mod_ssl mysql-server || exit 1
service httpd status >/dev/null 2>&1 || service httpd start

for i in {1..5}; do
sleep 1
service httpd status && break
[ "$i" -lt 5 ] || exit 1
done
chkconfig httpd on || exit 1

service mysqld status >/dev/null 2>&1 || service mysqld start
for i in {1..5}; do
sleep 1
service mysqld status && break
[ "$i" -lt 5 ] || exit 1
done
chkconfig mysqld on || exit 1

NEWMYSQLPASSWORD=`mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2`

/usr/bin/mysqladmin -u root password "$NEWMYSQLPASSWORD" || exit 1

cat <<EOT > /root/.my.cnf
[client]
host     = localhost
user     = root
password = $NEWMYSQLPASSWORD
socket   = /var/lib/mysql/mysql.sock
EOT
chmod 600 /root/.my.cnf

cat <<EOT > /etc/my.cnf
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
user=mysql
# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0
innodb_file_per_table
query-cache-size=16M
character-set-server=utf8
[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
[mysql]
default-character-set=utf8
EOT
service mysqld restart
#---------END OF Apache & MySQL---------#
#---------START OF Redmine---------#

yum -y install mysql-devel ImageMagick-devel || exit 1

USERNAME="rm_`mkpasswd -l 10 -C 0 -s 0`"
PASSWORD=`mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2`

echo "create database db_redmine default character set utf8;" | mysql --defaults-file=/root/.my.cnf
echo "grant all on db_redmine.* to $USERNAME@'localhost' identified by '$PASSWORD';" | mysql --defaults-file=/root/.my.cnf
echo "flush privileges;" | mysql --defaults-file=/root/.my.cnf

svn co http://svn.redmine.org/redmine/branches/3.3-stable /var/lib/redmine || exit 1

cat <<EOT > /var/lib/redmine/config/database.yml
production:
  adapter: mysql2
  database: db_redmine
  host: localhost
  username: $USERNAME
  password: $PASSWORD
  encoding: utf8
EOT

cd /var/lib/redmine || exit 1
gem install json || exit 1
bundle install --without development test || exit 1
bundle exec rake generate_secret_token || exit 1
RAILS_ENV=production bundle exec rake db:migrate

gem install passenger || exit 1
passenger-install-apache2-module -a
passenger-install-apache2-module --snippet > /etc/httpd/conf.d/passenger.conf
chown -R apache:apache /var/lib/redmine
echo 'DocumentRoot "/var/lib/redmine/public"' > /etc/httpd/conf/redmine.conf
echo "Include conf/redmine.conf" >> /etc/httpd/conf/httpd.conf
service httpd restart
#---------END OF Redmine---------#
>>>>>>> master
