require 'spec_helper'

cmd = 'usacloud server list'
logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

describe command(cmd) do
  its(:stdout) { should match /jenkins/ }
end

describe command(logchk) do
  its(:stdout) { should match /done$/ }
end
