require 'spec_helper'

cmd = '/root/terraform/terraform version'
logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

describe command(cmd) do
  its(:stdout) { should match /Terraform/ }
end

describe command(logchk) do
  its(:stdout) { should match /done$/ }
end
