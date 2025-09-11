require "json"
require "file_utils"
require "mt_helpers"
require "wait_group"
require "http/client"
require "http/headers"

require "./options"

class DownloaderCLI
  @options : DownloaderOptions
  @count = 1048575

  def initialize(options)
    @options = options
    @output_directory = File.expand_path(@options.output_directory)
    # the default data structures aren't concurrency safe
    @ranges = Synchronized(Array(Int64)).new
    @etags = Synchronized(Hash(Int64, String)).new
    @failed = Synchronized(Array(String)).new
    @successful = Atomic(Int64).new(0_i64)

    @type_add = ""
    @type_arg = ""
    if (options.type == "ntlm")
      @type_add = ".ntlm"
      @type_arg = "?mode=ntlm"
    end

    @etags_file = "#{@output_directory}/_etags#{@type_add}.json"
    if !@options.no_etags && File.exists?(@etags_file)
      @etags = Synchronized(Hash(Int64, String)).new(Hash(Int64, String).from_json(File.read(@etags_file)))
    end

    # hash length - 10 bit range
    @length = 35
    @length = 27 if @options.type == "ntlm"
  end

  def start
    return range_downloader if @options.range.size == 5
    return check_downloader if @options.check
    main_downloader
  end

  def range_downloader
    download_dir

    client = api_client
    download(client, range_unhex(@options.range))
    client.close
    puts "Fetched: #{@options.output_directory}/#{@options.range}#{@type_add}.txt"
  end

  # it isn't worth the effort to make this concurrent
  # while it can shave off some execution time  there's a race condition that makes
  # this unreliable and most fibers get 0 processed checks because the checks are
  # stupid fast
  def check_downloader
    checked = 0
    iter = 0
    while iter <= @count
      range = range_hex(iter)
      file = "#{@output_directory}/#{range}#{@type_add}.txt"
      file_relative = "#{@options.output_directory}/#{range}#{@type_add}.txt"
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

    puts "Total successful checks: #{checked}"
  end

  def main_downloader
    download_dir
    create_ranges
    create_workers
    write_etags
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

  def range_unhex(range)
    range.to_i(16)
  end

  def create_ranges
    range_count = @count
    while range_count >= 0
      @ranges << range_count
      range_count -= 1
    end
  end

  def set_etag(range, response)
    @etags[range] = response.headers["etag"] unless @options.no_etags
  end

  def write_file(range, response, rhex, content)
    File.write("#{@output_directory}/#{rhex}#{@type_add}.txt", content)
    set_etag(range, response)
    @successful.add(1)
    return 1
  end

  def strip_count(content)
    String.build do |io|
      content.each_line do |line|
        io.write(line.to_slice[0, @length])
        io << '\n'
      end
    end
  end

  def download(client, range, count = 0)
    rhex = range_hex(range)
    headers = HTTP::Headers.new
    headers["user-agent"] = "pwned-password-downloader/#{@options.version}"

    unless @options.no_etags
      etag = @etags[range]?
      unless etag.nil?
        headers["if-none-match"] = etag
      end
    end

    response = client.get("/range/#{rhex}#{@type_arg}", headers)
    case response.status_code
    when 200
      return write_file(range, response, rhex, strip_count(response.body)) if @options.strip == "count"
      return write_file(range, response, rhex, response.body.gsub("\r", "")) if @options.strip == "cr"
      return write_file(range, response, rhex, response.body)
    when 304
      @successful.add(1)
    when 500
      if count >= 5
        @failed << "#{rhex} failed to download with status code 500 after #{count} retries"
        return
      end

      sleep((count * 1).seconds)
      count += 1
      download(client, range, count)
    else
      @failed << "#{rhex} failed to download with status code #{response.status_code}"
    end
  end

  def worker_download(fid)
    # note: each fiber needs is own client as using a single client is not safe for
    # concurrent use by multiple fibers
    client = api_client
    loop do
      begin
        range = @ranges.pop
      rescue IndexError
        break
      end
      download(client, range)
    end
  end

  def create_workers
    stop = Atomic(Bool).new(false)
    progress_total = (@count + 1).to_f64
    progress_done = Channel(Nil).new
    spawn(name: "progress") do
      until stop.get
        remaining = @ranges.size.to_f64
        done = progress_total - remaining
        pct = (done / progress_total) * 100.0
        print("\rProgress: #{pct.format(decimal_places: 3)}%")
        sleep(2.seconds)
      end
      progress_done.send(nil)
    end

    if @options.parallelism == 1
      worker_download(0)
    else
      wg = WaitGroup.new
      @options.parallelism.times do |fid|
        wg.spawn do
          worker_download(fid)
        end
      end
      wg.wait
    end

    stop.set(true)
    progress_done.receive
    puts
  end

  def write_etags
    return if @options.no_etags

    File.write(@etags_file, @etags.to_json)
  end

  def print_stats
    puts "Total successful downloads: #{@successful.get}"

    if @failed.size > 0
      puts "Failures:\n\n#{@failed.join("\n")}"
    end
  end
end
