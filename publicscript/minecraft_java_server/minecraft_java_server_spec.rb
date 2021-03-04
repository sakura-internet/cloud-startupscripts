require 'spec_helper'

package = %w(curl jq openjdk-8-jre-headless screen)
processes = %w(java)
ports = %w(25565)
logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

package.each do |package_name|
  describe package(package_name) do
    it { should be_installed }
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

describe service('minecraft') do
  it { should be_enabled }
  it { should be_enabled.with_level(3) }
  it { should be_running }
  it { should be_running.under('systemd') }
end