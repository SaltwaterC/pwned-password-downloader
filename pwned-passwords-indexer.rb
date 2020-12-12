#!/usr/bin/env ruby

# frozen_string_literal: true

require 'optparse'
require 'fileutils'

include FileUtils

options = {
  index: "#{ENV['HOME']}/.pwn/idx"
}

bin = File.basename($PROGRAM_NAME)

op = OptionParser.new do |parser|
  parser.banner = "Usage: #{bin} --pwn " \
                  'pwned-passwords-sha1-ordered-by-hash-v7.txt'

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
rescue StandardError => e
  warn("ERROR: #{e}")
  $stderr.puts
  warn(op)
  exit(1)
end

if options[:pwn].nil?
  warn('ERROR: must specify the pwned passwords file path. See help.')
  $stderr.puts
  warn(op)
  exit(3)
end

unless Dir.exist?(options[:index])
  mkdir_p(options[:index])
  (0..255).each do |dir|
    dir = dir.to_s(16).upcase.rjust(2, '0')
    mkdir_p("#{options[:index]}/#{dir}")
  end
end

File.open(options[:pwn]) do |fd|
  prev = fd.readline[0..3]
  dir = prev[0..1]
  fd.rewind
  ostart = fd.pos

  fd.each_line do |line|
    next if line.start_with?(prev)

    offset = fd.pos - line.length
    dir = line[(0..1)]
    oend = offset
    File.write(
      "#{options[:index]}/#{dir}/#{prev}",
      "s: #{ostart}\ne: #{oend}"
    )
    ostart = offset
    prev = line[(0..3)]
  end

  File.write("#{options[:index]}/#{dir}/#{prev}", "s: #{ostart}\ne: #{fd.pos}")
end
