module Rainforest

  # ================================================================
  # Broadcast 
  #   <timestamp>, Annotation, <received_string>
  class AnnotationFormatter
    include Broadcaster

    def receive(string)
      self.broadcast("#{Utilities.seconds_since_2000}, Annotation, #{string}")
    end

  end

end
