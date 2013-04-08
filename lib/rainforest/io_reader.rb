module Rainforest

  # ================================================================
  # Read from an IO stream (or socket, or anything that responds to
  # #readline), broadcast a line at a time to listeners.
  class IOReader < ReaderProcess
    include Speaker

    def initialize(io = $stdin)
      super()
      @io = io
    end

    def reader_body
      broadcast(@io.readline.chomp)
    end

  end

end
