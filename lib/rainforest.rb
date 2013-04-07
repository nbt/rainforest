require 'pathname'

module Rainforest
  
  root = Pathname.new(ENV["PWD"])
  require root.join("lib/rainforest/broadcaster.rb")
  require root.join("lib/rainforest/reader_broadcaster.rb")
  Dir[root.join("lib/rainforest/**/*.rb").to_s].each { |f| require f }

end
