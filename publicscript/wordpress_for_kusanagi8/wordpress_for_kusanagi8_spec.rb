require 'spec_helper'

services = %w(mariadb monit nginx vsftpd xinetd hhvm)
processes = %w(mysqld monit nginx vsftpd xinetd hhvm)
ports = %w(21 80 443 2812 3306 9000)
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
