require "option_parser"

class DownloaderOptions
  getter :version, :output_directory, :parallelism, :check, :range, :no_etags

  @parallelism : Int32 = System.cpu_count.to_i32 * 8.to_i32

  def initialize(bin_path, version : String)
    @version = version
    @output_directory = "pwnedpasswords"
    @check = false
    @single = false
    @range = "" # avoid the ache of nilable types
    @no_etags = false

    bin = File.basename(bin_path)
    @parser = OptionParser.new
    @parser.banner = "Usage: #{bin}"
    parser_options
    error_handlers
    @parser.parse
  end

  def parser_options
    help_option
    version_option
    output_option
    parallelism_option
    range_option
    check_option
    no_etags_option
  end

  def error_handlers
    @parser.invalid_option do |flag|
      STDERR.puts("ERROR: #{flag} is not a valid option.")
      STDERR.puts
      STDERR.puts(@parser)
      exit(1)
    end

    @parser.missing_option do |flag|
      STDERR.puts("ERROR: #{flag} requires a value.")
      STDERR.puts
      STDERR.puts(@parser)
      exit(2)
    end
  end

  def help_option
    @parser.on("-h", "--help", "Show this help") do
      puts(@parser)
      exit(0)
    end
  end

  def version_option
    @parser.on("-v", "--version", "Print version number") do
      puts @version
      exit(0)
    end
  end

  def output_option
    desc_output = "Output directory. Defaults to #{@output_directory}"
    @parser.on("-d", "--output-directory #{@output_directory}", desc_output) do |opt|
      @output_directory = opt
    end
  end

  def parallelism_option
    desc_parallelism = "The number of parallel requests to make to Have I Been Pwned to download " \
                       "the hash ranges. If omitted or less than two, defaults to eight times the " \
                       "number of processors on the machine (#{@parallelism})."
    @parser.on("-p", "--parallelism #{@parallelism}", desc_parallelism) do |opt|
      parallelism = opt.to_i64
      parallelism = opt.to_i32
      @parallelism = parallelism if parallelism >= 2
    end
  end

  def range_option
    desc_range = "A single range to download in the output directory #{@output_directory}. " \
                 "Useful to recover when some ranges may fail the request."
    @parser.on("-r", "--range 5HEXCHARS", desc_range) do |opt|
      if opt.size == 5 && /^[0-9A-F]{5}$/.match(opt)
        @range = opt
        @no_etags = true
      else
        STDERR.puts("ERROR: expecting exactly 5 HEX upper case characters as range")
        STDERR.puts
        exit(4)
      end
    end
  end

  def check_option
    desc_check = "Check whether all ranges have been downloaded and whether their file size is > 0"
    @parser.on("-c", "--check", desc_check) do
      @check = true
      @no_etags = true
    end
  end

  def no_etags_option
    desc_no_etags = "Disable checking the ETags while downloading the ranges. Effectively, " \
                    "downloads everything from scratch. Does not update ETag list/save ETag file."
    @parser.on("-n", "--no-etags", desc_no_etags) do
      @no_etags = true
    end
  end
end
