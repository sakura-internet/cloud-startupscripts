require 'spec_helper'

services = %w(nginx mongodb crowi elasticsearch)
processes = %w(nginx mongod node java)

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

ports = %w(80 3000)
ports.each do |port_number|
  describe port(port_number) do
    it { should be_listening }
  end
end
