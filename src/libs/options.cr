require "option_parser"

class DownloaderOptions
  getter :version, :output_directory, :parallelism, :check, :range, :no_etags, :type, :strip, :merge, :merge_file

  @parallelism : Int32 = System.cpu_count.to_i32 * 8.to_i32

  def initialize(bin_path, version : String)
    @version = version.strip
    @output_directory = "pwnedpasswords"
    @check = false
    @single = false
    @range = "" # avoid the ache of nilable types
    @no_etags = false
    @type = "sha1"
    @strip = ""
    @merge = false
    @merge_file = ""

    bin = File.basename(bin_path)
    @parser = OptionParser.new
    @parser.banner = "Usage: #{bin}"
    parser_options
    error_handlers
    @parser.parse
    update_merge_file
  end

  def parser_options
    version_option
    help_option
    output_option
    parallelism_option
    range_option
    check_option
    no_etags_option
    type_option
    strip_option
    merge_option
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
                       "the hash ranges. Defaults to eight times the number of processors on the " \
                       "machine (#{@parallelism})."
    @parser.on("-p", "--parallelism #{@parallelism}", desc_parallelism) do |opt|
      parallelism = opt.to_i32
      @parallelism = parallelism if parallelism >= 1
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

  def type_option
    types = ["sha1", "ntlm"]
    desc_type = "Specify the hash type to download. One of: #{types.join(", ")}"
    @parser.on("-t", "--type #{@type}", desc_type) do |opt|
      if types.includes?(opt)
        @type = opt
      else
        STDERR.puts("ERROR: expecting one of #{types.join(", ")} as hash type. Got: #{opt}")
        STDERR.puts
        exit(3)
      end
    end
  end

  def strip_option
    strip = ["cr", "count"]
    desc_strip = "Specify what data to strip. One of: #{strip.join(", ")}. Note: count also strips CR"
    @parser.on("-s", "--strip #{@strip}", desc_strip) do |opt|
      if strip.includes?(opt)
        @strip = opt
      else
        STDERR.puts("ERROR: expecting one of #{strip.join(", ")} as strip mode. Got: #{opt}")
        STDERR.puts
        exit(5)
      end
    end
  end

  def merge_option
    desc_merge = "Merge all downloaded ranges in a single file. Defaults to pwnedpasswords.TYPE.txt"
    @parser.on("-m", "--merge [pwnedpasswords.#{@type}.txt]", desc_merge) do |opt|
      @merge_file = opt if opt.size > 0
      @merge = true
    end
  end

  def update_merge_file
    @merge_file = "pwnedpasswords.#{@type}.txt" if @merge && @merge_file.size == 0
  end
end
