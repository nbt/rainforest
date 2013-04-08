require 'active_support/core_ext'

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

    # Convert xml to a hash along with the following type conversions:
    # * Hexidecimal strings are converted to decimal except DeviceMacID and MeterMacID
    def xml_to_hash(xml)
      hash = Hash.from_xml(xml)
      convert_hex(hash, ["DeviceMacId", "MeterMacId"])
      hash
    end

    def convert_hex(hash, exclusions)
      hash.each_pair do |k, v|
        if v.instance_of?(Hash)
          convert_hex(v, exclusions)
        elsif !exclusions.member?(k) && v =~ /0x\d*/
          hash[k] = v.to_i(16)
        end
      end
    end
  end

end
