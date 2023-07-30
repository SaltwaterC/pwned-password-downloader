require "yaml"

puts "v#{YAML.parse(File.read("shard.yml"))["version"]}"
