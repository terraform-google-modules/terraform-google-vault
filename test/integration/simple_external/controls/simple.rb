# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'net/http'
require 'json'

LB_NAME = 'vault-external'
REGION = 'us-east4'

project_id = attribute('project_id')
control "Bastion Instance" do
  title "Simple Configuration"
  describe "Instance configuration" do
    subject { command("gcloud --project=#{project_id} compute forwarding-rules describe #{LB_NAME} --region #{REGION} --format=json") }
    its(:exit_status) { should eq 0 }
    its(:stderr) { should eq '' }
    let!(:data) { JSON.parse(subject.stdout) if subject.exit_status == 0 }
    let!(:lb_ip) { data['IPAddress'] }

    it 'should be running' do
      expect(data['portRange']).to eq("8200-8200")
    end

    it "should be healthy" do
      def vault_health_check(lb_ip)
        uri = URI("https://#{lb_ip}:8200/v1/sys/health")
        req = Net::HTTP::Get.new(uri.path)
        cert = nil
        res = nil
        # NOTE: Since Ruby cannot trivially make a request with a specified certificate,
        # we'll ensure that vault is running and has a certificate with the correct SAN
        20.times do
          begin
            res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |https|
              cert = https.peer_cert
              https.request(req)
            end
            san = cert.extensions.map(&:to_h).select do |ex|
              ex['oid'] == 'subjectAltName'
            end.first['value']
            return res, san
          rescue
            sleep 60
            next
          end
        end
      end

      res, san = vault_health_check(lb_ip)
      expect(res.code).to eq("501")
      expect(JSON.parse(res.body)['initialized']).to eq(false)
      expect(san).to include(lb_ip)
    end
  end
end
