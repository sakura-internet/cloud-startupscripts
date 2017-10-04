require 'spec_helper'

services = %w(gitlab-runsvdir postfix)
processes = %w(nginx bundle prometheus redis-server postgres master)
ports = %w(25 9100 9168 8080 9121 9090 9187 9168)
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
