require "file_utils"
require "option_parser"

include FileUtils

options = {
  :index => "#{ENV["HOME"]}/.pwn/idx",
}

bin = File.basename(PROGRAM_NAME)

op = OptionParser.parse do |parser|
  parser.banner = "Usage: #{bin} --pwn " \
                  "pwned-passwords-sha1-ordered-by-hash-v7.txt"

  desc_pwn = "Path to pwned passwords file"
  parser.on("-p", "--pwn pwned-passwords.txt", desc_pwn) do |opt|
    options[:pwn] = opt
  end

  desc_index = "Path to the directory where the index is going to be written." \
               " Defaults to ~/.pwn/idx"
  parser.on("-i", "--index ~/.pwn/idx", desc_index) do |opt|
    options[:index] = opt
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

unless options[:pwn]?
  STDERR.puts("ERROR: must specify the pwned passwords file path. See help.")
  STDERR.puts
  STDERR.puts(op)
  exit(3)
end

unless Dir.exists?(options[:index])
  mkdir_p(options[:index])
  (0..255).each do |dir|
    dir = dir.to_s(16).upcase.rjust(2, '0')
    mkdir_p("#{options[:index]}/#{dir}")
  end
end

File.open(options[:pwn]) do |fd|
  prev = "0000"
  ostart = 0

  fd.each_line do |line|
    next if line.starts_with?(prev)

    offset = fd.pos - line.bytesize - 2
    dir = line[(0..1)]
    oend = offset
    File.write(
      "#{options[:index]}/#{dir}/#{prev}",
      "s: #{ostart}\ne: #{oend}"
    )
    ostart = offset
    prev = line[(0..3)]
  end

  File.write("#{options[:index]}/FF/FFFF", "s: #{ostart}\ne: #{fd.pos}")
end
