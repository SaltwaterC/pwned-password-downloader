require "./.gen/version"
require "./src/downloader/options"
require "./src/downloader/cli"

options = DownloaderOptions.new(PROGRAM_NAME, version)
cli = DownloaderCLI.new(options)
cli.start
