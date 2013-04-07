module Rainforest

  # ================================================================
  # Echo to standard output
  class Echo
    include Broadcaster

    def receive(string)
      puts(string)
      self.broadcast(string)
    end

  end

end
