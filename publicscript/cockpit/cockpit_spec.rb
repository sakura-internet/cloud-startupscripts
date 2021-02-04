require 'spec_helper'

package= %w(cockpit)
services = %w(cockpit.socket)
ports = %w(9090)
logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

package.each do |package_name|
  describe package(package_name) do
    it { should be_installed }
  end
end

services.each do |service_name|
  describe service(service_name) do
    it { should be_enabled }
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