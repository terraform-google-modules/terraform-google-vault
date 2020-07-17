#!/usr/bin/env ruby
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

# For saftey, default to dry run
dry_run = !ARGV.include?('-no-dry-run')
lines = `terraform plan -no-color | grep -e '#.*\.cluster\.' | grep -v data`.split("\n").map(&:chomp)
reg = /# (.*?) will/
new_paths = lines.map{ |l| reg.match(l)[1] }
path_tuples = new_paths.map{ |p| [p] }
path_tuples.map! do |pt|
  ["'#{pt.first.gsub('module.cluster.', '')}'", "'#{pt.first}'"]
end

if dry_run
  STDERR.puts "===> Executing with -dry-run. To actually run, execute:"
  STDERR.puts "===>   gen_upgrage_commands.rb -no-dry-run | bash"
end

path_tuples.each do |pt|
  puts "terraform state mv #{'-dry-run' if dry_run} #{pt[0]} #{pt[1]}"
end
