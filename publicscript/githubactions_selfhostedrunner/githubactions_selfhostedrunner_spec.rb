require 'spec_helper'

logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

describe service('docker')do
  it { should be_enabled }
  it { should be_running }
end

describe service('actions.runner.*') do
  it { should be_running }
end

describe command('systemctl is-enabled $(grep -m1 SVC_NAME /opt/actions-runner/svc.sh | sed -s \'s/ /_/g\' | awk -F= \'{print $2}\' | tr -d \'"\' | tr -d \'\n\')') do
  its(:stdout) { should match /enabled/ }
end

describe command(logchk) do
  its(:stdout) { should match /done$/ }
end
