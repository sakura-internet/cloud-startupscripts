require 'spec_helper'

services = %w(httpd mariadb zabbix-agent zabbix-server)
services.each do |service_name|
  describe service(service_name) do
    it { should be_enabled }
    it { should be_running }
  end
end

ports = %w(80 3306 10050 10051)
ports.each do |port_number|
  describe port(port_number) do
    it { should be_listening }
  end
end
