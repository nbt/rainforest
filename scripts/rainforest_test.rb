# Read data from a simulated Rainforest EMU-2, log to a file and echo to stdout
# USAGE:
# $ ruby scripts/rainforest_test.rb

load 'lib/rainforest.rb'
include Rainforest
(e = EmuSim.new) | Coalescer.new | CSVFormatter.new | (f = FileLogger.new("log/test.log")) | Echo.new
(r = IOReader.new) | AnnotationFormatter.new | f

e.start
r.start
e.reader_thread.join
