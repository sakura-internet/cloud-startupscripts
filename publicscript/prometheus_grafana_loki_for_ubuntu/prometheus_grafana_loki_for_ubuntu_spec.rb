require 'rspec'
require 'spec_helper'
require 'net/http'
require 'json'

NGINX_PORT = 80
GRAFANA_PORT = 3000
LOKI_PORT = 3100
ADMIN_PASSWORD_IN_JENKINS="pxw-nca0vyx-uyx_RFJ"

services = {
  "prometheus": "prometheus.service",
  "sakuracloud_exporter": "sakuracloud_exporter.service",
  "loki": "loki.service",
  # the below services doesn't have the extension '.service'
  "grafana-server": "grafana-server",
  "nginx": "nginx",
}

ports = [NGINX_PORT, LOKI_PORT]

# test all systemd services are enabled and running.
services.each do |service_name, service_file|
  # `should be_running` checks the service process with `ps aux`
  # but the command cannot detect the service if it has the extension `.service`
  # so we pass `service_name` to service()
  describe service(service_name) do
    it { should be_running }
  end

  describe service(service_file) do
    it { should be_enabled }
  end
end

# test all tcp port is listening on the expected.
ports.each do |port_number|
  describe port(port_number) do
    it { should be_listening }
  end
end

# test expected data sources are exist on Grafana.
uri = URI.parse('http://localhost:%d/api/datasources' % [GRAFANA_PORT])
req = Net::HTTP::Get.new(uri.request_uri)
req.basic_auth("admin", ADMIN_PASSWORD_IN_JENKINS)
res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
describe res do
  its(:code) { should eq "200" }
end

body = JSON.parse(res.body)
# typeName => data-source's url
actual_sources = Hash.new
body.each do |source|
  actual_sources[source["typeName"]] = source["url"]
end

RSpec.describe body do
  it "should have one or more data sources" do
    expect(body.length).to be > 0
  end

  it "should have Loki and Prometheus" do
    expect(actual_sources["Loki"]).to eq "http://localhost:3100"
    expect(actual_sources["Prometheus"]).to eq "http://localhost:9090"
  end
end
