require 'spec_helper'

logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

describe service('docker')do
  it { should be_enabled }
  it { should be_running }
end

describe service('actions.runner.*') do
  it { should be_enabled }
  it { should be_running }
end

describe command(logchk) do
  its(:stdout) { should match /done$/ }
end
