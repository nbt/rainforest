# Capture raw XML packets from the EMU-2
# usage:
# $ ruby scripts/rainforest_sampler.rb

load 'lib/rainforest.rb'
include Rainforest
(e = USBIO.new) | FileLogger.new("log/rainforest_samples.log")
e.start
e.reader_thread.join
