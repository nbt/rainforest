module Rainforest

  module Utilities
    extend self

    UTC_EPOCH = Time.utc(2000, 1, 1).to_i

    # TODO: better names!

    # Return seconds since midnight, Jan 1 2000, UTC
    def utc_seconds(time)
      time.to_i - UTC_EPOCH
    end

    def utc_string(time)
      sprintf("0x%x", utc_seconds(time))
    end
    
    # hex format
    def utc_now_string
      utc_string(Time.now)
    end

    # decimal format
    def seconds_since_2000
      utc_seconds(Time.now)
    end

  end

end
