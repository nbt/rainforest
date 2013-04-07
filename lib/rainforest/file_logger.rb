module Rainforest

  # ================================================================
  # Write create logging file
  class FileLogger
    require 'logger'
    include Broadcaster
    
    def initialize(logname = "log")
      super()
      @logger = Logger.new(logname, 'daily')
      @logger.level = Logger::INFO
      @logger.formatter = proc {|severity, datetime, progname, msg| "#{msg}\n" }
    end

    def receive(string)
      @logger.info(string)
      self.broadcast(string)
    end

  end

end
