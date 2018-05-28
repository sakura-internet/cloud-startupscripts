require 'spec_helper'

services = %w(nginx postfix redis postgresql-9.6 mastodon-sidekiq mastodon-streaming mastodon-web)
processes = %w(nginx master redis-server postgres bundle node)
ports = %w(25 80 443 3000 5432 6379)
logchk = 'ls /root/.sacloud-api/notes/[0-9]*.done'

services.each do |service_name|
  describe service(service_name) do
    it { should be_enabled }
    it { should be_running }
  end
end

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

