#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'

include FileUtils

options = {
  index: "#{ENV["HOME"]}/.pwn/idx"
}

bin = File.basename($PROGRAM_NAME)

op = OptionParser.new do |parser|
  parser.banner = "Usage: #{bin} --pwn " \
                  "pwned-passwords-sha1-ordered-by-hash-v4.txt"

  desc_pwn = 'Path to pwned passwords file'
  parser.on('-p', '--pwn pwned-passwords.txt', desc_pwn) do |opt|
    options[:pwn] = opt
  end

  desc_index = 'Path to the directory where the index is going to be written.' \
               ' Defaults to ~/.pwn/idx'
  parser.on('-i', '--index ~/.pwn/idx', desc_index) do |opt|
    options[:index] = opt
  end

  parser.on('-h', '--help', 'Show this help') do
    puts(parser)
    exit
  end
end

begin
  op.parse!
rescue StandardError => err
  STDERR.puts("ERROR: #{err}")
  STDERR.puts
  STDERR.puts(op)
  exit(1)
end

if options[:pwn].nil?
  STDERR.puts('ERROR: must specify the pwned passwords file path. See help.')
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
  prev = '0000'
  ostart = 0

  fd.each_line do |line|
    if line.start_with?(prev)
      next
    else
      offset = fd.pos - line.length
      dir = line[(0..1)]
      oend = offset
      File.write(
        "#{options[:index]}/#{dir}/#{prev}",
        "s: #{ostart}\ne: #{oend}"
      )
      ostart = offset
    end

    prev = line[(0..3)]
  end

  File.write("#{options[:index]}/FF/FFFF", "s: #{ostart}\ne: #{fd.pos}")
end
