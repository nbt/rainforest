module Rainforest

  # Receive XML fragments from EMU-2, broadcast CSV-formatted line
  # of the form:
  #   <timestamp>, RecordType, args*
  class EmuCSV
    include Speaker
    include Listener

    TAG_METHODS = Hash.new(:unrecognized)
    TAG_METHODS["InstantaneousDemand"] = :instantaneous_demand
    TAG_METHODS["TimeCluster"] = :time_cluster
    TAG_METHODS["CurrentSummationDelivered"] = :current_summation_delivered
    TAG_METHODS["ConnectionStatus"] = :connection_status

    def listen(xml)
      hash = Utilities.xml_to_hash(xml)
      self.send(TAG_METHODS[self.tag(hash)], hash)
    end

    def tag(hash)
      hash.first.first
    end

    def fields(hash)
      hash.first.last
    end

    def unrecognized(hash)
      self.broadcast("#{self.tag(hash)}, (unrecognized)")
    end

    def instantaneous_demand(hash)
      tag = self.tag(hash)
      fields = self.fields(hash)

      device_mac_id = fields["DeviceMacId"]
      meter_mac_id = fields["MeterMacId"]
      time_stamp = fields["TimeStamp"]
      demand = fields["Demand"]
      multiplier = fields["Multiplier"]
      self.broadcast("#{time_stamp}, #{tag}, #{demand*multiplier}, #{device_mac_id}, #{meter_mac_id}")
    end

    def current_summation_delivered(hash)
      fields = self.fields(hash)

      device_mac_id = fields["DeviceMacId"]
      meter_mac_id = fields["MeterMacId"]
      time_stamp = fields["TimeStamp"]
      summation_delivered = fields["SummationDelivered"]
      summation_received = fields["SummationReceived"]
      multiplier = fields["Multiplier"]
      multiplier = 1 if multiplier == 0
      self.broadcast("#{time_stamp}, #{self.tag(hash)}, #{summation_delivered*multiplier}, #{summation_received*multiplier}, #{device_mac_id}, #{meter_mac_id}")
    end

    def time_cluster(hash)
      fields = self.fields(hash)

      device_mac_id = fields["DeviceMacId"]
      meter_mac_id = fields["MeterMacId"]
      utc_time = fields["UTCTime"]
      local_time = fields["LocalTime"]
      self.broadcast("#{utc_time}, #{self.tag(hash)}, #{local_time}, #{device_mac_id}, #{meter_mac_id}")
    end

    def connection_status(hash)
      fields = self.fields(hash)

      device_mac_id = fields["DeviceMacId"]
      meter_mac_id = fields["MeterMacId"]
      status = fields["Status"]
      description = fields["Description"]
      status_code = fields["StatusCode"]
      ext_pan_id = fields["ExtPanId"]
      channel = fields["Channel"]
      short_addr = fields["ShortAddr"]
      link_strength = fields["LinkStrength"]
      self.broadcast(sprintf("%d, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s",
                             Utilities.seconds_since_2000, # should be local time, not UTC
                             self.tag(hash),
                             link_strength,
                             status,
                             description,
                             status_code,
                             ext_pan_id,
                             channel,
                             short_addr,
                             device_mac_id,
                             meter_mac_id))
    end

  end

end
