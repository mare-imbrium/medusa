#!/usr/bin/env ruby
# ----------------------------------------------------------------------------- #
#         File: meds.rb
#  Description: prints when a medicine will be finishing and sends alert
#               Also, allow input and update of meds.
#       Author:  j kepler
#         Date: 2018-02-28 - 23:13
#  Last update: 2019-05-27 10:10
#      License: MIT License
# ----------------------------------------------------------------------------- #
# CHANGELOG:
#  2018-10-21 - readline suddenly not working, values don't show during "mod" and go as nil
#  2018-12-08 - write to log file so I know when last I bought something. sometimes I am
#                out of medicine but the software shows I have it.
#               This does not give an exact idea of how much I bought, just the stock on that day
#               which could be a correction.
#  2019-01-12 - Put mod in a loop since i modify several at a shot
#  2019-02-13 - Display only med name in mod menu, and use smenu in place of fzf
#               since we get a matrix like menu
# ----------------------------------------------------------------------------- #
# TODO:
#
# ----------------------------------------------------------------------------- #
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

#  edit a variable and return value as in zsh vared.
#  newstock = vared(newstock, "Enter current stock: ")
## 2019-01-02 - this has stopped working. we should revert to OLD_vared (see seen.rb)
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
# include? exist? each_pair split gsub join empty?

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
    # 2019-02-08 - maybe we can comment off a med that is paused or discontinued
    next if line =~ /^#/

    ctr += 1
    next if ctr <= 1

    cols = line.split(sep)
    name = cols[0]
    daily = cols[1].to_f
    stock = cols[2].to_i
    as_on = cols[3]
    as_on_jd = Date.parse(cols[3]).jd
    # 2019-02-08 - if we are not taking a medicine, i have made the stock zero
    next if daily == 0

    finish_on_jd = as_on_jd + (stock / daily)
    finish_on = Date.jd(finish_on_jd)
    balance = (stock/daily) - (Date.today.jd - as_on_jd)
    balance = balance.to_i
    # left is how many tablets are left
    left = (balance*daily).to_i
    file_a << [ name, daily, stock, as_on, finish_on, balance, left ]
  }
  return file_a
end # }}}
def print_all file_a # {{{
  format='%-25s %5s %5s %-12s %-12s %10s %6s'
  puts color(format % [ "Medicine", "daily", "stock", "as_on" , "finish_on" , "days_left", "left"], "yellow", "on_black", "bold")
  file_a.each_with_index {|cols, ix|
    name = cols[0]
    daily = cols[1]
    stock = cols[2]
    as_on = cols[3]
    finish_on = cols[4]
    balance = cols[5]
    left = cols[6]
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
    puts color(format % [ name, daily, stock, as_on , finish_on , balance, left], fgcolor, bgcolor, attrib)
  }
end # }}}

def change_line filename, argv=[] # {{{
  # argv can have name of med or pattern and balance for today
  while true
    ## argv is being repeated. that is an issue
    num, line = select_row filename, argv
    return unless num
    puts line.join("\t")
    stock = line[2]
    # if user passed a number then ask if stock to be replaced, else prompt
    if argv.count == 2
      newstock = argv[1]
    else
      newstock = stock
    end
    savedval = newstock
    puts "stock was #{line[2]} as on #{line[3]}. You passed #{newstock}"
    newstock = vared(newstock, "Enter current stock: ")
    newstock = savedval if newstock.nil? or newstock == ""  ## 2018-10-21 - readline not working
    puts "Got :#{newstock}:" if $opt_debug
    puts "Got nil :#{newstock}:" if newstock.nil? or newstock == ""
    raise ArgumentError, "Newstock nil" unless newstock



    # allow user to edit date, default to today
    newdate = Date.today.to_s
    savedval = newdate
    newdate = vared(newdate, "Enter as on date #{savedval}: ")
    newdate = savedval if newdate.nil? or newdate == ""  ## 2018-10-21 - readline not working
    print "How much did you buy: "
    bought = $stdin.gets
    if bought
      bought = bought.chomp.to_i
    else
      bought = 0
    end
    puts "Got :#{newdate}:" if $opt_debug
    puts "line is #{num}" if $opt_debug
    puts "Bought is #{bought}" if $opt_debug
    raise ArgumentError, "Newdate nil" unless newdate
    newline = line.dup
    newline[2] = newstock
    newline[3] = newdate
    replace_line filename, num, newline
    log_line newline, bought
    puts
    print ">> Modify another item? y/n: "
    yesno = $stdin.gets.chomp
    if yesno != "y"
      break
    end
  end # while

end # }}}
def replace_line filename, lineno, newline  # {{{
  sep = "~"
  arr = _read filename
  num = lineno.to_i - 1
  arr[num] = newline.join(sep)
  _write(filename, arr)
end # }}}

## log the line to a file with date so we know when we entered what
## @param newline array of medicine name, stock, date
def log_line newline, bought
  sep = "~"
  newline << bought
  str = newline.join(sep)
  File.open($logfile, 'a') {|f| f.puts(str) } # or f.puts or f << str
end

# prompt user with rows for selection
# return selected row in an array
def select_row filename, argv=[] # {{{
  myarg = argv.first
  sep = "~"

  ## display med names to user, this displays entire line with a number
  #str=%x{ nl #{filename} | fzf --query="#{myarg}" -1 -0}

  # prompt user with medicine names. Some meds have spaces in it, so -W tells smenu not to separate on that.
  # Reject header row with tail, and reject commented out meds
  str = %x{ cut -f1 -d~ #{filename} | grep -v "^#" | tail -n +2 | sort | smenu -t -W$'\n' }

  return nil,nil if str.nil? or str.chomp.size == 0
  # 2019-02-13 - now we only display medicine name,so get the rest of the row
  str = %x{ grep -n "#{str}" #{filename} }
  #tmp = str.chomp.split("\t")
  #puts str
  tmp = str.chomp.split(":")
  #puts tmp[0]
  #puts tmp[1]

  # returns lineno, and array containing rest
  return tmp[0], tmp[1].split(sep)
end # }}}

# adds a new medicine to the file.
# TODO should check if already present
def add_line filename, argv=[] # {{{

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
end  # }}}
def append_to_file filename, line # {{{
  open(filename, 'a') do |f|
    f.puts line
  end
end  # }}}

def alert_me filename, args=[] # {{{
  file_a = read_file_in_loop filename
  arr = []

  # sort by balance
  file_a.sort_by! { |s| s[5] }

  file_a.each_with_index do |cols, _ix|
    name, daily, stock, as_on, finish_on, balance, left = cols
    if balance < 12
      #arr << "#{name} will finish on #{finish_on}. #{balance} days left."
      arr << "%-28s will finish on #{finish_on}. #{balance} days left." % [name, finish_on, balance]
    end
  end

  return if arr.empty?

  # send contents of arr as a message using mail.sh.
  str = arr.join("\n")
  email_id = ENV['MAIL_ID']
  puts email_id if $opt_debug
  if $opt_cron
    #out = %x{ echo "#{str}" | ~/bin/mail.sh -s "Medicine alert!" #{email_id} 2>&1}
    out = %x{ echo "#{str}" | /Users/rahul/bin/mail.sh -s "Medicine alert" #{email_id} }
    # checking this 2018-03-25 - since cron is not sending it at all.
    #puts str
    #puts "#{out}"
  else
    puts str
    puts "#{out}"
  end

  # install as crontab
end # }}}

def find_line array, patt # {{{
  array.each_with_index {|e, ix|
    name = e.first
    if name =~ /name/
      return e
    end
  }
  return nil
end # }}}


if __FILE__ == $0
  include Color
  filename = nil
  $opt_verbose = false
  $opt_debug = false
  $opt_quiet = false
  $opt_cron = false
  begin
    # http://www.ruby-doc.org/stdlib/libdoc/optparse/rdoc/classes/OptionParser.html
    require 'optparse'
    ## TODO filename should come in from -f option
    filename = File.expand_path("~/work/projects/meds/meds.txt");
    $logfile = File.expand_path("~/work/projects/meds/meds.log");
    options = {}
    subtext = <<HELP
Commonly used command are:
   mod :     update stocks. mod dilzem 45
   low :     report on medicines running low (less than 10 days stock)
   add :     add a new medicine. e.g., add aspirin 1 25
HELP
    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"

      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        options[:verbose] = v
        $opt_verbose = v
      end
      opts.on("--crontab", "Send email, don't display on stdout") do |v|
        $opt_cron = v
      end
      opts.on("--debug", "Show debug info") do
        options[:debug] = true
        $opt_debug = true
      end
      opts.on("-q", "--quiet", "Run quietly") do |v|
        $opt_quiet = true
      end
      opts.separator ""
      opts.separator subtext
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
