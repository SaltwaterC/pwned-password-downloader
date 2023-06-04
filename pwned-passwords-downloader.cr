require "file_utils"
require "mt_helpers"
require "http/client"
require "option_parser"
require "crystal-wait-group"

include FileUtils

# XXX: this whole needs a refactor to look a bit more put together

bin = File.basename(PROGRAM_NAME)

class Options
  property output = "pwnedpasswords"
  property parallelism : Int64 = System.cpu_count * 8
  property check = false
  property range = ""
end

options = Options.new

op = OptionParser.parse do |parser|
  parser.banner = "Usage: #{bin}"

  desc_output = "Name of the output. Defaults to #{options.output}, which writes the output " \
                "to #{options.output}.txt for single file output, or a directory called #{options.output}."
  parser.on("-ou", "--output #{options.output}", desc_output) do |opt|
    options.output = opt
  end

  desc_parallelism = "The number of parallel requests to make to Have I Been Pwned to download " \
                     "the hash ranges. If omitted or less than two, defaults to eight times the " \
                     "number of processors on the machine (#{options.parallelism})."
  parser.on("-p", "--parallelism #{options.parallelism}", desc_parallelism) do |opt|
    parallelism = opt.to_i
    options.parallelism = parallelism if parallelism >= 2
  end

  desc_range = "A single range to download in the output directory #{options.output}. " \
               "Useful to recover when some ranges may fail the request."
  parser.on("-r", "--range HEX", desc_range) do |opt|
    if opt.size == 5
      options.range = opt
    else
      STDERR.puts "ERROR: expecting exactly 5 HEX characters as range"
      STDERR.puts
      exit(1)
    end
  end

  desc_check = "Check whether all ranges have been downloaded and whether their file size is > 0"
  parser.on("-c", "--check", desc_check) do
    options.check = true
  end

  parser.on("-h", "--help", "Show this help") do
    puts(parser)
    exit
  end

  parser.invalid_option do |flag|
    STDERR.puts("ERROR: #{flag} is not a valid option.")
    STDERR.puts
    STDERR.puts(parser)
    exit(1)
  end

  parser.missing_option do |flag|
    STDERR.puts("ERROR: #{flag} requires a value.")
    STDERR.puts
    STDERR.puts(parser)
    exit(2)
  end
end

op.parse

output_dir = "#{Dir.current}/#{options.output}"
mkdir_p(output_dir)

ranges = Synchronized(Array(Int64)).new
stats = Synchronized(Hash(Int64, Int64)).new
count = 1048575
range_count = count
while range_count >= 0
  ranges << range_count
  range_count -= 1
end

def range_hex(range)
  range.to_s(16, upcase: true).rjust(5, '0')
end

def download(output_dir, client, range_hex)
  response = client.get("/range/#{range_hex}")
  if response.status_code == 200
    File.write("#{output_dir}/#{range_hex}.txt", response.body)
    File.write("#{output_dir}/#{range_hex}.etag", response.headers["etag"])
    return 1
  else
    STDERR.puts "ERROR: range #{range_hex} failed to download with status code #{response.status_code}"
    return 0
  end
end

def api_client
  HTTP::Client.new("api.pwnedpasswords.com", tls: true)
end

def worker_download(ranges, output_dir, stats, fid)
  # note: each fiber needs is own client as using a single client is not safe for
  # concurrent use by multiple fibers
  client = api_client
  downloaded = 0
  loop do
    if ranges.size > 0
      downloaded += download(output_dir, client, range_hex(ranges.pop))
    else
      stats[fid] = downloaded
      break
    end
  end
end

def check_download(count, output_dir, output)
  checked = 0
  iter = 0
  while iter <= count
    range = range_hex(iter)
    file = "#{output_dir}/#{range}.txt"
    file_relative = "#{output}/#{range}.txt"
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
end

if options.range.size == 5
  client = api_client
  download(output_dir, client, options.range)
  client.close
  puts "Fetched: #{options.output}/#{options.range}.txt"
  exit(0)
end

# it isn't worth the effort to make this concurrent
# while it can shave off almost a second of execution time from 1.6 to 0.5 on reasonably fast hardware
# there's a race condition that makes this unreliable and most fibers get 0 processed checks because
# the checks are stupid fast
if options.check
  total_checks = check_download(count, output_dir, options.output)
  puts "Total checks: #{total_checks}"
  exit(0)
end

wg = WaitGroup.new
options.parallelism.times do |fid|
  wg.spawn do
    worker_download(ranges, output_dir, stats, fid)
  end
end
wg.wait

total_downloads = 0
stats.each do |fid, downloads|
  puts "Fiber #{fid} downloaded #{downloads} ranges"
  total_downloads += downloads
end
puts "Total downloads: #{total_downloads}"
