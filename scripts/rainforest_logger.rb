# Read energy data from the Rainforest EMU-2 and write it to a log file
# usage:
# $ ruby scripts/rainforest_test.rb

load 'lib/rainforest.rb'
include Rainforest
(e = USBIO.new) | Coalescer.new | CSVFormatter.new | (f = FileLogger.new("log/rainforest2.log"))
(r = IOReader.new) | AnnotationFormatter.new | f
e.start
r.start
e.reader_thread.join
