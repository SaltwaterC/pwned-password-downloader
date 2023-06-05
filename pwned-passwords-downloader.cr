require "./src/downloader/options"
require "./src/downloader/cli"

options = DownloaderOptions.new(PROGRAM_NAME)
cli = DownloaderCLI.new(options)
cli.start
