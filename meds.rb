#!/usr/bin/env ruby
# ----------------------------------------------------------------------------- #
#         File: meds.rb
#  Description: prints when a medicine will be finishing and sends alert
#               Also, will allow input and update of meds.
#       Author:  r kumar
#         Date: 2018-02-28 - 23:13
#  Last update: 2018-03-03 08:42
#      License: MIT License
# ----------------------------------------------------------------------------- #
#
require 'pp'
require 'readline'
require 'date'
require 'color' # see ~/work/projects/common/color.rb
  # print color("Hello there black reverse on yellow\n", "black", "on_yellow", "reverse")

# --- some common stuff --- # {{{
# Taken from imdb/seen.rb

# readline version of gets
def input(prompt="", newline=false)
  prompt += "\n" if newline
  Readline.readline(prompt, true).squeeze(" ").strip
end
def agree(prompt="")
  x = input(prompt)
  return true if x.upcase == "Y"
  false
end

#  edit a variable and return value as in zsh vared.
#  newstock = vared(newstock, "Enter current stock: ")
def vared var, prompt=">"
  Readline.pre_input_hook = -> do
    Readline.insert_text var
    Readline.redisplay
    # Remove the hook right away.
    Readline.pre_input_hook = nil
  end
  begin 
  str = Readline.readline(prompt, false)
  rescue Exception => e
    return nil
  end
  str
end

def get_ratings prompt, ratings
  Readline::HISTORY.clear
  Readline::HISTORY.push(*ratings) 
  input prompt
end

# # taken from sed.rb in bugzy
# read the given filename into an array
def _read filename
  d = []
  File.open(filename).each { |line|
    # remove blank lines. NOTE this may not be needed in other programs
    next if line.chomp == ""
    d << line
  }
  return d
end

# write the given array to the filename
def _write filename, array
  File.open(filename, "w") do |file| 
    array.each { |row| file.puts row }
  end
end
#
# --- end common stuff # }}}
## date in yyyy-mm-dd format
today = Date.today.to_s
now = Time.now.to_s
# include? exist? each_pair split gsub

def get_int message="Enter a number: ", lower=0, upper=5 # {{{
  print message
  str = STDIN.gets
  Integer(str) rescue 0
end
def get_float message="Enter a number: ", lower=0, upper=5
  print message
  str = STDIN.gets
  Float(str) rescue 0.0
end # }}}


# this reads the file in a loop.
# It should not print, just put the data into a data structure
# so it can be called for either complete printing, or sending an alert via crontab
# etc.
def read_file_in_loop filename # {{{
  sep = '~'
  ctr = 0
  file_a = []
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
    balance = balance.to_i
    file_a << [ name, daily, stock, as_on, finish_on,  balance ]
  }
  return file_a
end # }}}
def print_all file_a # {{{
  format='%-25s %5s %5s %-12s %-12s %-4s' 
  puts color(format % [ "Medicine", "daily", "stock", "as_on" , "finish_on" , "days_left"], "yellow", "on_black", "bold")
  file_a.each_with_index {|cols, ix| 
    name = cols[0]
    daily = cols[1]
    stock = cols[2]
    as_on = cols[3]
    finish_on = cols[4]
    balance = cols[5]
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
  }
end # }}}

def change_line filename, argv=[]
  # argv can have name of med or pattern and balance for today
  num, line = select_row filename, argv
  puts line.join("\t")
  stock = line[2]
  # if user passed a number then ask if stock to be replaced, else prompt
  if argv.count == 2
    newstock = argv[1]
  else
    newstock = stock
  end
  puts "stock was #{line[2]} as on #{line[3]}. You passed #{newstock}"
  newstock = vared(newstock, "Enter current stock: ")
  puts "Got #{newstock} " if $opt_debug


  # allow user to edit date, default to today
  newdate = Date.today.to_s
  newdate = vared(newdate, "Enter as on date: ")
  puts "Got #{newdate} " if $opt_debug
  puts "line is #{num}" if $opt_debug
  newline = line.dup
  newline[2] = newstock
  newline[3] = newdate
  replace_line filename, num, newline
end
def replace_line filename, lineno, newline
  sep = "~"
  arr = _read filename
  num = lineno.to_i - 1
  arr[num] = newline.join(sep)
  _write(filename, arr)
end
# prompt user with rows for selection
# return selected row in an array
def select_row filename, argv=[] # {{{
  myarg = argv.first
  sep = "~"
  str=%x{ nl #{filename} | fzf --query="#{myarg}" -1 -0}

  return nil if str.nil? or str.chomp.size == 0
  tmp = str.chomp.split("\t")

  # returns lineno, and array containing rest
  return tmp[0], tmp[1].split(sep)
end # }}}

# adds a new medicine to the file.
# TODO should check if already present
def add_line filename, argv=[]

  name, dosage, stock, newdate = argv
  unless name
    print "Enter name of medicine: "
    name = gets.chomp
  end
  unless dosage
    dosage = vared("1", "Enter dosage: ")
  end
  stock = vared("0", "Enter stock: ") unless stock
  unless newdate
    newdate = Date.today.to_s
    newdate = vared(newdate, "Enter as on date: ")
  end
  str =  "#{name}~#{dosage}~#{stock}~#{newdate}"
  puts str if $opt_debug
  append_to_file filename, str
end
def append_to_file filename, line
  open(filename, 'a') do |f|
    f.puts line
  end
end

def alert_me filename, args=[]
  file_a = read_file_in_loop filename
  arr = []
  file_a.each_with_index {|cols, ix| 
    name, daily, stock, as_on, finish_on, balance = cols
    if balance < 10
      arr << "#{name} will finish on #{finish_on}. #{balance} days left."
    end
  }

  return if arr.empty?
  # TODO send contents of arr as a message using mail.sh.
  str = arr.join("\n")
  email_id = ENV['MAIL_ID']
  puts email_id
  out = %x{ echo "#{str}" | ~/bin/mail.sh -s "Medicine alert!" #{email_id} 2>&1}

  # install as crontab
end

def find_line array, patt # {{{
  array.each_with_index {|e, ix| 
    name = e.first
    if name =~ /name/
      return e
    end
  }
  return nil
end # }}}
  

def old_read_file_in_loop filename# {{{
  exit 1
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
    balance = balance.to_i
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
end # }}}

if __FILE__ == $0
  include Color
  filename = nil
  $opt_verbose = false
  $opt_debug = false
  $opt_quiet = false
  begin
    # http://www.ruby-doc.org/stdlib/libdoc/optparse/rdoc/classes/OptionParser.html
    require 'optparse'
    ## TODO filename should come in from -f option
    filename= "meds.txt";
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
    unless File.exist? filename
      $stderr.puts "File: #{filename} does not exist. Aborting"
      exit 1
    end
    if ARGV.count == 0
      file_a = read_file_in_loop filename
      print_all file_a
      exit 0
    end
    command = ARGV.shift
    case command
    when "add","a"
      add_line filename, ARGV
    when "mod","m"
      change_line filename, ARGV
    when "low","l"
      alert_me filename, ARGV
    else
      puts "don't know how to handle #{command}!"
      exit 1
    end

  ensure
  end
end

