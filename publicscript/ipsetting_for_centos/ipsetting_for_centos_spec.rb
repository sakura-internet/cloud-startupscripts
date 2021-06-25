require 'spec_helper'
logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

Dir.glob('/etc/sysconfig/network-scripts/ifcfg*') do |filename|
  describe file(filename) do
    eth_x = `basename #{filename} | awk -F- '{print $2}'`.chomp

    ipaddress = `ip address show "#{eth_x}" | grep 'inet ' | awk '{print $2}' | sed -e 's|/.*||'`.chomp
    its(:content) { should match %r{IPADDR=#{ipaddress}} }

    prefix = `ip address show "#{eth_x}" | grep 'inet ' | awk '{print $2}' | sed -e 's|.*/||'`.chomp
    its(:content) { should match %r{PREFIX=#{prefix}} }
  end
end

describe command(logchk) do
  its(:stdout) { should match /done$/ }
end
