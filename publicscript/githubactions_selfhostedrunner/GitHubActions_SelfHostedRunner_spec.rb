require 'spec_helper'

services = %w(docker actions.runner.*)
logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

services.each do |service_name|
  describe service(service_name) do
    it { should be_enabled }
    it { should be_running }
  end
end

describe command(logchk) do
  its(:stdout) { should match /done$/ }
end
