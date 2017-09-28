require 'spec_helper'

cmd = 'su - vuls -c "vuls scan 2>/dev/null | grep ^localhost | grep -v Error"'
logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

describe command(cmd) do
  its(:stdout) { should match /^localhost/ }
end

describe command(logchk) do
  its(:stdout) { should match /done$/ }
end
