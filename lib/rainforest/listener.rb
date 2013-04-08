module Rainforest

  module Listener

    # Primarily for documentation: a Listener must implement a #listen
    # method.
    def listen(msg)
      raise SubclassResponsibility.new(__method__)
    end

  end

end
