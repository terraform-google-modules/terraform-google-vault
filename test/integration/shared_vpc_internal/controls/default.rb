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
require 'json'

LB_NAME = 'vault-internal'
REGION = 'us-west1'

project_id = attribute('project_id')

control "Vault" do
  title "Shared VPC Configuration"
  describe "ILB configuration" do
    subject { command("gcloud --project=#{project_id} compute forwarding-rules describe #{LB_NAME} --region #{REGION} --format=json") }
    its(:exit_status) { should eq 0 }
    its(:stderr) { should eq '' }
    let!(:data) { JSON.parse(subject.stdout) if subject.exit_status == 0 }

    it 'should be internal' do
      expect(data['loadBalancingScheme']).to eq("INTERNAL")
    end
  end

  describe "Instance configuration" do
    subject { command("gcloud --project=#{project_id} compute instances list --format=json") }
    its(:exit_status) { should eq 0 }
    its(:stderr) { should eq '' }
    let!(:data) { JSON.parse(subject.stdout) if subject.exit_status == 0 }

    it 'should be running' do
      data.each do |inst|
        expect(inst['name']).to start_with("vault")
        expect(inst['status']).to eq("RUNNING")
      end
    end
  end
end
