# Read energy data from the Rainforest EMU-2 and write it to a log file
# usage:
# $ ruby scripts/rainforest_test.rb

load 'lib/rainforest.rb'
include Rainforest
(e = USBIO.new) | Coalescer.new | CSVFormatter.new | FileLogger.new("log/rainforest.log") | Echo.new
e.start
e.reader_thread.join
