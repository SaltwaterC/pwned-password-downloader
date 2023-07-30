require "./libs/options"
require "./libs/cli"

macro version
  {{ run("./macro/version.cr").stringify }}
end

options = DownloaderOptions.new(PROGRAM_NAME, version)
cli = DownloaderCLI.new(options)
cli.start
