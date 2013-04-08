module Rainforest

  # ================================================================
  # Echo to standard output and rebroadcast
  class Echo
    include Listener
    include Speaker

    def listen(string)
      puts(string)
      self.broadcast(string)
    end

  end

end
