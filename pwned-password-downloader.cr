version = "v1.0.2" # keep it in sync with shard.yml unless there's a better way

require "./src/downloader/options"
require "./src/downloader/cli"

options = DownloaderOptions.new(PROGRAM_NAME, version)
cli = DownloaderCLI.new(options)
cli.start
