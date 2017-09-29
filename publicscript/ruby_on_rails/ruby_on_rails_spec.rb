require 'spec_helper'

cmd = 'su - rubyuser -c "ruby --version"'
logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

describe command(cmd) do
  its(:stdout) { should match /^ruby 2/ }
end

describe command(logchk) do
  its(:stdout) { should match /done$/ }
end

