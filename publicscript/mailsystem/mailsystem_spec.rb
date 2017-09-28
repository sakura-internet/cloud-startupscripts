require 'spec_helper'

services = %w(nginx mariadb postfix dovecot slapd opendkim clamav-milter yenma php-fpm)
processes = %w(nginx mysqld master dovecot slapd opendkim clamd clamav-milter yenma php-fpm)
ports = %w(24 25 80 110 143 389 443 465 587 993 995 3306 4190 8891 9000 10025 10026)
logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

services.each do |service_name|
  describe service(service_name) do
    it { should be_enabled }
    it { should be_running }
  end
end

processes.each do |proc_name|
  describe process(proc_name) do
    it { should be_running }
  end
end

ports.each do |port_number|
  describe port(port_number) do
    it { should be_listening }
  end
end

describe command(logchk) do
  its(:stdout) { should match /done$/ }
end

