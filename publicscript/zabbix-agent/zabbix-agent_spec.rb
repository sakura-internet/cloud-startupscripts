require 'spec_helper'

services = %w(zabbix-agent)
services.each do |service_name|
  describe service(service_name) do
    it { should be_enabled }
    it { should be_running }
  end
end

ports = %w(10050)
ports.each do |port_number|
  describe port(port_number) do
    it { should be_listening }
  end
end
