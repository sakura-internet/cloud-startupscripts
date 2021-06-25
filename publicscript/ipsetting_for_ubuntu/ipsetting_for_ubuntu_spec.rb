require 'spec_helper'
logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

describe file('/etc/netplan/10-ipsetting-generated-by-startupscript.yaml') do
  eths = `ip l | egrep 'eth[0-9]+' | awk '{print $2}' | tr -d ':'`.split(/\n/)

  eths.each do | eth_x |
    next if eth_x == "eth0"
    ipaddress = `ip address show "#{eth_x}" | grep 'inet ' | awk '{print $2}' | sed -e 's|/.*||'`.chomp
    prefix = `ip address show "#{eth_x}" | grep 'inet ' | awk '{print $2}' | sed -e 's|.*/||'`.chomp
    its(:content) { should match "
    #{eth_x}:
      addresses:
        - #{ipaddress}/#{prefix}" }
  end
end

describe command(logchk) do
  its(:stdout) { should match /done$/ }
end
