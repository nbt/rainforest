module Rainforest

  # ================================================================
  # Output recognized XML fragments as CSV strings
  #
  # TODO: Replace Nokogiri parsing with simple Hash.from_xml(string),
  # pass resulting hash to other parts of the system.  (Big change).

  class CSVFormatter
    include Speaker

    require 'nokogiri'

    # Map a tag ("InstantaneousDemand") to a method (:instantaneous_demand)
    TAG_METHODS = Hash.new(:unrecognized)
    TAG_METHODS["InstantaneousDemand"] = :instantaneous_demand
    TAG_METHODS["TimeCluster"] = :time_cluster
    TAG_METHODS["CurrentSummationDelivered"] = :current_summation_delivered
    TAG_METHODS["ConnectionStatus"] = :connection_status

    def listen(string)
      doc = Nokogiri.XML(string)
      return unless doc && doc.root && (tag = doc.root.name)
      self.send(TAG_METHODS[tag], doc)
    end

    def unrecognized(doc)
      self.broadcast("#{doc.root.name}, (unrecognized)")
    end

    def instantaneous_demand(doc)
      device_mac_id = doc.at_xpath("//DeviceMacId").text
      meter_mac_id = doc.at_xpath("//MeterMacId").text
      time_stamp = doc.at_xpath("//TimeStamp").text.to_i(16)
      demand = doc.at_xpath("//Demand").text.to_i(16)
      multiplier = doc.at_xpath("//Multiplier").text.to_i(16)
      self.broadcast("#{time_stamp}, #{doc.root.name}, #{demand*multiplier}, #{device_mac_id}, #{meter_mac_id}")
    end

    def current_summation_delivered(doc)
      device_mac_id = doc.at_xpath("//DeviceMacId").text
      meter_mac_id = doc.at_xpath("//MeterMacId").text
      time_stamp = doc.at_xpath("//TimeStamp").text.to_i(16)
      summation_delivered = doc.at_xpath("//SummationDelivered").text.to_i(16)
      summation_received = doc.at_xpath("//SummationReceived").text.to_i(16)
      multiplier = doc.at_xpath("//Multiplier").text.to_i(16)
      multiplier = 1 if multiplier == 0
      self.broadcast("#{time_stamp}, #{doc.root.name}, #{summation_delivered*multiplier}, #{summation_received*multiplier}, #{device_mac_id}, #{meter_mac_id}")
    end

    def time_cluster(doc)
      device_mac_id = doc.at_xpath("//DeviceMacId").text
      meter_mac_id = doc.at_xpath("//MeterMacId").text
      utc_time = doc.at_xpath("//UTCTime").text.to_i(16)
      local_time = doc.at_xpath("//LocalTime").text.to_i(16)
      self.broadcast("#{utc_time}, #{doc.root.name}, #{local_time}, #{device_mac_id}, #{meter_mac_id}")
    end

    def connection_status(doc)
      device_mac_id = doc.at_xpath("//DeviceMacId").text
      meter_mac_id = doc.at_xpath("//MeterMacId").text
      status = doc.at_xpath("//Status").text
      description = (f = doc.at_xpath("//Description")) && f.text
      status_code = (f = doc.at_xpath("//StatusCode")) && f.text
      ext_pan_id = (f = doc.at_xpath("//ExtPanId")) && f.text
      channel = (f = doc.at_xpath("//Channel")) && f.text
      short_addr = (f = doc.at_xpath("//ShortAddr")) && f.text
      link_strength = doc.at_xpath("//LinkStrength").text
      self.broadcast(sprintf("%d, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s",
                             Utilities.seconds_since_2000, # should be local time, not UTC
                             doc.root.name,
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
