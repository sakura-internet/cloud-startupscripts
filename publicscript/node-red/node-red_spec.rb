require 'spec_helper'

processes = %w(node)
ports = %w(1880)
logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

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
