# Read data from a simulated Rainforest EMU-2, log to a file and echo to stdout
# USAGE:
# $ irb
# >> load 'rainforest_test.rb'

require 'lib/rainforest.rb'
include Rainforest
(e = EmuSim.new) | Coalescer.new | CSVFormatter.new | FileLogger.new("log/test.log") | Echo.new
e.start
