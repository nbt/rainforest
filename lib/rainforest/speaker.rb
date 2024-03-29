require 'monitor'

module Rainforest

  # ================================================================
  # The speaker half of a simple speaker / listener model:
  # self.broadcast(msg) will cause all listeners to receive
  # listener.listen(msg)
  #
  module Speaker
    require 'set'
    include MonitorMixin        # for synchronize

    def broadcast(msg)
      listeners.each do |listener| 
        listener.synchronize { listener.listen(msg) }
      end
    end

    def add_listener(listener)
      listeners.add(listener)
      listener
    end
    alias_method("|", :add_listener)

    def remove_listener(listener)
      listeners.delete(listener)
    end

    def has_listener?(listener)
      listeners.member?(listener)
    end

    def listeners
      @listeners ||= Set.new
    end

  end

end
