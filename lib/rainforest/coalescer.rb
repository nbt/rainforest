module Rainforest

  # ================================================================
  # collect lines of text until we have a complete XML fragment
  class Coalescer
    include Listener
    include Speaker

    # state 0: ignore input until we see <tag>.  Save tag.
    # state 1: collect input unil we see <\tag>.  Emit saved input, state = 0

    def initialize()
      super()
      @state = 0
      @collected_input = ""
    end

    def listen(string)
      if (@state == 0)
        return unless (string =~ /.*?(<([^\/][^>]*)>.*)/m)
        # $1 is the entire string starting with the opening <
        # $2 is the tag
        @tag = $2
        string = $1
        @state = 1
      end
      if (string =~ /(.*<\/#{@tag}>)(.*)/m)
        # $1 is everything upto and including closing tag
        # $2 is any remnant after the closing tag
        @collected_input += $1
        self.broadcast(@collected_input)
        @collected_input = $2
        @state = 0
      else
        # didn't find closing tag
        @collected_input += string
      end
    end

  end

end
