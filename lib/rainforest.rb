require 'pathname'

module Rainforest
  
  root = Pathname.new(ENV["PWD"])
  puts("=== root = #{root}")
  require root.join("lib/rainforest/speaker.rb")
  require root.join("lib/rainforest/reader_process.rb")
  Dir[root.join("lib/rainforest/**/*.rb").to_s].each { |f| require f }

end
