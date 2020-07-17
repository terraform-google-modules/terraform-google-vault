#!/usr/bin/env ruby

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
