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

RSpec.shared_examples "instance_group_behavior" do |params|
  project_id = params[:project_id]
  region     = params[:region] || 'us-east4'
  ig_name    = params[:ig_name] || 'vault-igm'
  deadline   = params[:deadline] || 300

  ##
  # Wait until an instance has booted
  def wait_for_boot(project_id, instance)
    tries=60
    delay=5
    while tries > 0
      c = command("gcloud --project=#{project_id} compute instances get-serial-port-output #{instance}")
      if c.stdout =~ /GCEMetadataScripts: Finished running startup scripts/
        return c.stdout
      end
      tries = tries - 1
      sleep(delay)
    end
    return c.stdout
  end

  ##
  # Wait until an instance has currentAction: "NONE" (STAGING => VERIFYING => NONE)
  def wait_for_action(project_id, ig_name, region)
    tries=60
    delay=5
    instances = []
    while tries > 0
      list = command("gcloud --project=#{project_id} compute instance-groups managed list-instances #{ig_name} --region=#{region} --format=json")
      instances = list.exit_status == 0 ? JSON.parse(list.stdout) : []
      if instances.all? { |i| i['currentAction'] == 'NONE' }
        return instances
      end
      tries = tries - 1
      sleep(delay)
    end
    return list
  end

  describe "instances" do
    # Wait until the instance group is stable, otherwise the instance status is
    # in flux, for example could be "STAGING" or "RUNNING" depending on the
    # health check.  DEADLINE seconds is intentional to provide quick feedback
    # to the contributor and to ensure the instance recovers quickly when
    # unhealthy.  The startup script should strive to get the health check
    # passing as quickly as possible.
    before :all do
      # Note, this block intentionally uses the unconventional before :all form
      # and instance variables because the API calls are time consuming and we
      # need the data only once to assert against it.
      @wait = command("gcloud --project=#{project_id} compute instance-groups managed wait-until --stable --timeout=#{deadline} #{ig_name} --region=#{region}")
      # Wait until there are no actions on each instance
      @instances = wait_for_action(project_id, ig_name, region)
      # Array<String> serial port output from each instance in the group.
      @consoles = @instances.collect {|i| wait_for_boot(project_id, i['instance']) }
    end

    it "should become stable in #{deadline} seconds" do
      expect(@wait.exit_status).to eq(0)
      expect(@wait.stdout).to include("Group is stable")
    end

    it 'should at least one instance in the group' do
      expect(@instances).not_to be_empty
    end

    it 'should be running' do
      @instances.each do |inst|
        expect(inst['instanceStatus']).to eq("RUNNING"), "expected all to be RUNNING, got #{@instances.inspect}"
      end
    end

    it 'should be healthy' do
      @instances.each do |inst|
        health_states = inst['instanceHealth'].collect do |h|
          h['detailedHealthState']
        end
        expect(health_states).to all(eq("HEALTHY")), "expected #{inst.inspect} to have all instanceHealth detailedHealthState HEALTHY values."
      end
    end

    # This example is intended to help troubleshoot startup failures by giving
    # visibility into the startup script output directly in the build output
    # log.
    it 'should run startup scripts successfully with exit status 0' do
      expect(@consoles).not_to be_empty
      @consoles.each do |serial_console|
        expect(serial_console).to include('startup-script exit status 0')
      end
    end
  end
end
