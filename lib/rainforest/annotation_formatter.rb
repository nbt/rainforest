require './lib/rainforest/listener.rb'

module Rainforest

  # ================================================================
  # Upon receiving a message, decorate it with
  #    <timestamp>, Annotation, <message>
  # and re-broadcast it
  #
  class AnnotationFormatter
    include Listener
    include Speaker

    def listen(string)
      self.broadcast("#{Utilities.seconds_since_2000}, Annotation, #{string}")
    end

  end

end
