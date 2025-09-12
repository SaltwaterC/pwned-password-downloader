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
    return merge_downloads if @options.merge
    main_downloader
  end

  def range_downloader
    download_dir

    client = api_client
    download(client, range_unhex(@options.range))
    client.close
    puts "Fetched: #{@options.output_directory}/#{@options.range}#{@type_add}.txt"
  end

  def check_downloader
    puts "Starting download checks for #{@options.type} type"
    checked = Atomic(Int64).new(0_i64)
    failures = Synchronized(Array(String)).new
    next_idx = Atomic(Int64).new(0_i64)

    worker = -> do
      loop do
        i = next_idx.add(1)
        break if i > @count
        rhex = range_hex(i)
        file = "#{@output_directory}/#{rhex}#{@type_add}.txt"
        file_relative = "#{@options.output_directory}/#{rhex}#{@type_add}.txt"
        if File.exists?(file)
          if File.size(file) > 0
            checked.add(1)
          else
            failures << "ERROR: #{file_relative} is empty"
          end
        else
          failures << "ERROR: #{file_relative} is missing"
        end
      end
    end

    if @options.parallelism <= 1
      worker.call
    else
      wg = WaitGroup.new
      par = @options.parallelism
      par.times do
        wg.spawn { worker.call }
      end
      wg.wait
    end

    puts "Total successful checks: #{checked.get}"
    if failures.size > 0
      puts failures.join("\n")
    end
    return @count + 1 == checked.get
  end

  def merge_downloads
    checked = check_downloader
    unless checked
      STDERR.puts "ERROR: local ranges failed checks. Can not merge inconsistent download"
      exit(100)
    end

    puts "Merge downloaded ranges into: #{@options.merge_file}"

    flush_every = 1024_i64
    processed_ranges = 0_i64
    progress_total = (@count + 1).to_f64
    suffix_len = (@options.type == "ntlm") ? 27 : 35

    File.open(@options.merge_file, "w+") do |io|
      buffer = IO::Memory.new
      idx = 0_i64
      while idx <= @count
        rhex = range_hex(idx)
        path = "#{@output_directory}/#{rhex}#{@type_add}.txt"
        File.each_line(path) do |line|
          next if line.empty?

          buffer << rhex
          buffer << line
          buffer << "\n"
        end

        processed_ranges += 1
        if (processed_ranges % flush_every) == 0
          io.write(buffer.to_slice)
          buffer.clear
          pct = (processed_ranges.to_f64 / progress_total) * 100.0
          print "\rMerge progress: #{pct.format(decimal_places: 3)}%"
        end

        idx += 1
      end

      if buffer.bytesize > 0
        io.write(buffer.to_slice)
      end
    end
    print "\rMerge progress: 100.000%\n"
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
    when 500, 502
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
