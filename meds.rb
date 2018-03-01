#!/usr/bin/env ruby -w
# ----------------------------------------------------------------------------- #
#         File: meds.rb
#  Description: prints when a medicine will be finishing and sends alert
#               Also, will allow input and update of meds.
#       Author:  r kumar
#         Date: 2018-02-28 - 23:13
#  Last update: 2018-03-01 10:59
#      License: MIT License
# ----------------------------------------------------------------------------- #
#
require 'pp'
#require 'sqlite3'
require 'date'
require 'color' # see ~/work/projects/common/color.rb
  # print color("Hello there black reverse on yellow\n", "black", "on_yellow", "reverse")

# --- some common stuff ---
## date in yyyy-mm-dd format
today = Date.today.to_s
now = Time.now.to_s
# include? exist? each_pair split gsub

def get_int message="Enter a number: ", lower=0, upper=5
  print message
  str = STDIN.gets
  Integer(str) rescue 0
end
def get_float message="Enter a number: ", lower=0, upper=5
  print message
  str = STDIN.gets
  Float(str) rescue 0.0
end


def read_file_in_loop filename
  sep = '~'
  ctr = 0
  format='%-25s %5s %5s %-12s %-12s %-4s' 
  puts color(format % [ "Medicine", "daily", "stock", "as_on" , "finish_on" , "balance"], "yellow", "on_black")
  File.open(filename).each { |line|
    line = line.chomp
    next if line =~ /^$/
    ctr += 1
    next if ctr <=1
    cols = line.split(sep)
    name = cols[0]
    daily = cols[1].to_f
    stock = cols[2].to_i
    as_on = cols[3]
    as_on_jd = Date.parse(cols[3]).jd
    finish_on_jd = as_on_jd + (stock/daily)
    finish_on = Date.jd(finish_on_jd)
    balance = (stock/daily) - (Date.today.jd - as_on_jd)
    bg = "on_black"
    fg = "white"
    att = "normal"
    code, fgcolor, bgcolor, attrib = case balance
    when 0..5
      ["B", "red", bg, "bold"]
    when 6..12
      ["C", "white", bg, att]
    when 13..1000
      ["C", "green", bg, att]
    when -1000..-1
      ["A", fg, bg, "reverse"]
    else
      ["?", "yellow", "on_red", att]
    end
    puts color(format % [ name, daily, stock, as_on , finish_on , balance], fgcolor, bgcolor, attrib)
    #puts line 
    # puts line if line =~ /blue/
  }
end

if __FILE__ == $0
  include Color
  filename = nil
  $opt_verbose = false
  $opt_debug = false
  $opt_quiet = false
  begin
    # http://www.ruby-doc.org/stdlib/libdoc/optparse/rdoc/classes/OptionParser.html
    require 'optparse'
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"

      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        options[:verbose] = v
        $opt_verbose = v
      end
      opts.on("--debug", "Show debug info") do 
        options[:debug] = true
        $opt_debug = true
      end
      opts.on("-q", "--quiet", "Run quietly") do |v|
        $opt_quiet = true
      end
    end.parse!

    p options if $opt_debug
    p ARGV if $opt_debug

    # --- if processing just one file ---------
    filename=ARGV[0] || "meds.txt";
    unless File.exist? filename
      $stderr.puts "File: #{filename} does not exist. Aborting"
      exit 1
    end
    if ARGV.count == 0
      read_file_in_loop filename
    end

  ensure
  end
end

