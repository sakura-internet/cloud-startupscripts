require 'spec_helper'

services = %w(nginx elasticsearch kibana td-agent )
processes = %w(nginx java node ruby)
ports = %w(80 9200 5601 8888)

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
