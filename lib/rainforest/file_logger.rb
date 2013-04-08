module Rainforest

  require 'logger'

  # ================================================================
  # Listen for messages.  Write message to logfile before
  # re-broadcasting.
  class FileLogger
    include Listener
    include Speaker
    
    def initialize(logname = "log")
      super()
      @logger = Logger.new(logname, 'daily')
      @logger.level = Logger::INFO
      @logger.formatter = proc {|severity, datetime, progname, msg| "#{msg}\n" }
    end

    def listen(string)
      @logger.info(string)
      self.broadcast(string)
    end

  end

end
