require "file_utils"
require "mt_helpers"
require "http/client"
require "crystal-wait-group"

require "./options"

class DownloaderCLI
  @options : DownloaderOptions
  @count = 1048575

  def initialize(options)
    @options = options
    @output_directory = "#{Dir.current}/#{@options.output_directory}"
    # the default data structures aren't concurrency safe
    @ranges = Synchronized(Array(Int64)).new
    @stats = Synchronized(Hash(Int64, Int64)).new
  end

  def start
    range_downloader if @options.range.size == 5
    check_downloader if @options.check
    main_downloader
  end

  def range_downloader
    download_dir

    client = api_client
    download(client, @options.range)
    client.close
    puts "Fetched: #{@options.output_directory}/#{@options.range}.txt"

    exit(0)
  end

  # it isn't worth the effort to make this concurrent
  # while it can shave off some execution time from 1.3 down to 0.5 on reasonably fast hardware
  # there's a race condition that makes this unreliable and most fibers get 0 processed checks because
  # the checks are stupid fast
  def check_downloader
    checked = 0
    iter = 0
    while iter <= @count
      range = range_hex(iter)
      file = "#{@output_directory}/#{range}.txt"
      file_relative = "#{@options.output_directory}/#{range}.txt"
      if File.exists?(file)
        if File.size(file) > 0
          checked += 1
        else
          STDERR.puts "ERROR: #{file_relative} is empty"
        end
      else
        STDERR.puts "ERROR: #{file_relative} is missing"
      end
      iter += 1
    end
    checked

    puts "Total successful checks: #{checked}"
    exit(0)
  end

  def main_downloader
    download_dir
    create_ranges
    create_workers
    print_stats
  end

  def api_client
    HTTP::Client.new("api.pwnedpasswords.com", tls: true)
  end

  def download_dir
    FileUtils.mkdir_p(@output_directory)
  end

  def range_hex(range)
    range.to_s(16, upcase: true).rjust(5, '0')
  end

  def create_ranges
    range_count = @count
    while range_count >= 0
      @ranges << range_count
      range_count -= 1
    end
  end

  def download(client, range_hex)
    response = client.get("/range/#{range_hex}")
    if response.status_code == 200
      File.write("#{@output_directory}/#{range_hex}.txt", response.body)
      File.write("#{@output_directory}/#{range_hex}.etag", response.headers["etag"])
      return 1
    else
      STDERR.puts "ERROR: range #{range_hex} failed to download with status code #{response.status_code}"
      return 0
    end
  end

  def worker_download(fid)
    # note: each fiber needs is own client as using a single client is not safe for
    # concurrent use by multiple fibers
    client = api_client
    downloaded = 0
    loop do
      if @ranges.size > 0
        downloaded += download(client, range_hex(@ranges.pop))
      else
        @stats[fid] = downloaded
        break
      end
    end
  end

  def create_workers
    wg = WaitGroup.new
    @options.parallelism.times do |fid|
      wg.spawn do
        worker_download(fid)
      end
    end
    wg.wait
  end

  def print_stats
    total_downloads = 0
    @stats.each do |_fid, downloads|
      total_downloads += downloads
    end
    puts "Total successful downloads: #{total_downloads}"
  end
end