require "yaml"
require "file_utils"

version_cr = <<-VERSION
def version
  "v#{YAML.parse(File.read("shard.yml"))["version"]}"
end

VERSION

FileUtils.mkdir_p(".gen")
File.write(".gen/version.cr", version_cr)
