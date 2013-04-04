require 'serialport'
require 'monitor'

# TODO: split into separate files

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

  # ================================================================
  # A simple speaker / listener model: self.broadcast(msg) will cause
  # all listeners to receive rcvr.receive(msg)
  #
  module Broadcaster
    require 'set'
    include MonitorMixin

    def broadcast(msg)
      listeners.each do |listener| 
        listener.synchronize { listener.receive(msg) }
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

  # ================================================================
  # Abstract class for Broadcaster with a reader thread
  class ReaderBroadcaster
    include Broadcaster

    def start
      @reader_thread = Thread.new {
        begin
          self.read_setup if self.respond_to?(:read_setup)
          read_loop
        ensure
          self.read_teardown if self.respond_to?(:read_teardown)
        end
      }
    end

    def stop
      @reader_thread = nil
    end

    def reader_thread
      @reader_thread
    end

    def read_loop
      $stderr.puts("=== #{self.class} entering read loop")
      thread = @reader_thread
      begin
        while (thread == @reader_thread)
          self.reader_body
        end
      rescue => e
        $stderr.puts(e.inspect)
        $stderr.puts(e.backtrace)
      end
      $stderr.puts("=== #{self.class} exiting read loop")
    end

    # normally subclassed
    def reader_body
      sleep(10)
    end

  end

  # ================================================================
  # Low-level communication with the Rainforest Automation EMU-2.  
  # 
  # Usage:
  #   emu = USBIO.new("/dev/tty.usbserial")
  #
  # The command:
  #   emu.start
  # opens communication to the EMU via the USB/serial port and spawns
  # a reader thread.  When a line of data is available from the EMU_2,
  # it is broadcast to any listener(s).
  #
  # At any point, after emu.start and before emu.stop, you may do:
  #   emu.write(string)
  # which will write the raw string to the EMU_2.
  #
  # Finally, 
  #   emu.stop
  # will shut down the asyncrhonous reader thread and close the port.
  #
  class USBIO < ReaderBroadcaster
    
    BAUD_RATE = 115200
    DATA_BITS = 8
    STOP_BITS = 1
    PARITY = SerialPort::NONE

    # TODO: dynamic discovery of port.
    DEFAULT_PORTNAME = "/dev/tty.usbserial"

    def initialize(portname = DEFAULT_PORTNAME)
      super()
      @portname = portname
    end
    
    def read_setup
      @port = SerialPort.open(@portname, BAUD_RATE, DATA_BITS, STOP_BITS, PARITY)
    end

    def read_teardown
      @port.close
    end

    def reader_body
      broadcast(@port.readline.chomp)
    end
    
    def write(string)
      @port.write(string)
    end
    
  end

  # ================================================================
  # Read data from a file in lieu of a real device.  Does not attempt
  # to throttle time.
  class FileSource < ReaderBroadcaster
  
    def initialize(filename)
      super()
      @filename = filename
    end

    def read_setup
      @file = File.open(@filename)
    end

    def read_teardown
      @file.close
    end

    def reader_body
      if @file.eof?
        self.stop
      else
        broadcast(@file.readline.chomp)
      end
    end

    def write(string)
      broadcast(string.chomp)
    end

  end

  # ================================================================
  # Simulate an EMU-2 device with same semantics as the USBIO device.
  # The only real difference is that it doesn't need the physical
  # USB device.
  class EmuSim < ReaderBroadcaster
    include Broadcaster

    def reader_body
      xml =<<EOF
<InstantaneousDemand>
  <DeviceMacId>0xd8d5b9000000014b</DeviceMacId>
  <MeterMacId>0x000781000028c07d</MeterMacId>
  <TimeStamp>#{Utilities.utc_now_string}</TimeStamp>
  <Demand>#{sprintf("0x%x", rand(200))}</Demand>
  <Multiplier>0x00000001</Multiplier>
  <Divisor>0x000003e8</Divisor>
  <DigitsRight>0x03</DigitsRight>
  <DigitsLeft>0x06</DigitsLeft>
  <SuppressLeadingZero>Y</SuppressLeadingZero>
</InstantaneousDemand>
EOF
      broadcast(xml)
      sleep(4)
    end

    def write(string)
      $stderr.puts("=== write #{string}")
    end

  end

  class IOReader < ReaderBroadcaster

    def initialize(io = $stdin)
      super()
      @io = io
    end

    def reader_body
      broadcast(@io.readline.chomp)
    end

  end

  # ================================================================
  # collect lines of text until we have a complete XML fragment
  class Coalescer
    include Broadcaster

    # state 0: ignore input until we see <tag>.  Save tag.
    # state 1: collect input unil we see <\tag>.  Emit saved input, state = 0

    def initialize()
      super()
      @state = 0
      @collected_input = ""
    end

    def receive(string)
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

  # ================================================================
  # Broadcast 
  #   <timestamp>, Annotation, <received_string>
  class AnnotationFormatter
    include Broadcaster

    def receive(string)
      self.broadcast("#{Utilities.seconds_since_2000}, Annotation, #{string}")
    end

  end

  # ================================================================
  # Output recognized XML fragments as CSV strings
  class CSVFormatter
    include Broadcaster

    require 'nokogiri'

    # Map a tag ("InstantaneousDemand") to a method (:instantaneous_demand)
    TAG_METHODS = Hash.new(:unrecognized)
    TAG_METHODS["InstantaneousDemand"] = :instantaneous_demand
    TAG_METHODS["TimeCluster"] = :time_cluster
    TAG_METHODS["CurrentSummationDelivered"] = :current_summation_delivered
    TAG_METHODS["ConnectionStatus"] = :connection_status

    def receive(string)
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

  # ================================================================
  # Write create logging file
  class FileLogger
    require 'logger'
    include Broadcaster
    
    def initialize(logname = "log")
      super()
      @logger = Logger.new(logname, 'daily')
      @logger.level = Logger::INFO
      @logger.formatter = proc {|severity, datetime, progname, msg| "#{msg}\n" }
    end

    def receive(string)
      @logger.info(string)
      self.broadcast(string)
    end

  end

  # ================================================================
  # Echo to standard output
  class Echo
    include Broadcaster

    def receive(string)
      puts(string)
      self.broadcast(string)
    end

  end

  # ================================================================
  class Command

    TIME = "time"
    PRICE = "price"
    DEMAND = "demand"
    SUMMATION = "summation"
    MESSAGE = "message"

    ENABLED = "Y"
    DISABLED = "N"

    REFRESH = "Y"
    NO_REFRESH = "N"

    DELIVERED = "Delivered"
    RECEIVED = "Received"

    # ================================================================
    # RAVEn FEATURES

    # 1. Command: INITIALIZE
    def self.initialize
      named_command(__method__)
    end

    # 2. Command: RESTART
    def self.restart
      named_command(__method__)
    end

    # 3. Command: FACTORY_RESET
    def self.factory_reset
      named_command(__method__)
    end

    # 4. Command: GET_CONNECTION_STATUS
    def self.get_connection_status
      named_command(__method__)
    end

    # 6. Command: GET_DEVICE_INFO
    def self.get_device_info
      named_command(__method__)
    end

    # 8. Command: GET_SCHEDULE
    def self.get_schedule(event_type = nil, *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    *(event_type ? tag("Event", event_type) : [])
                    )
    end
    
    # 10. Command: SET_SCHEDULE
    def self.set_schedule(event_type, frequency, enabled, *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    tag("Event", event_type),
                    tag("Frequency", sprintf("0x%X", frequency.to_i)),
                    tag("Enabled", enabled))
    end
    
    # 11. Command: SET_SCHEDULE_DEFAULT
    def self.set_schedule_default(event_type, *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    tag("Event", event_type))
    end
    
    # 12. Command: GET_METER_LIST
    def self.get_meter_list
      named_command(__method__)
    end

    # ================================================================
    # METER FEATURE

    # 1. Command: GET_METER_INFO
    def self.get_meter_info(*meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)))
    end

    # 3. Command: GET_NETWORK_INFO
    def self.get_network_info
      named_command(__method__)
    end

    # 5. Command: SET_METER_INFO
    def set_meter_info(nickname, account, auth, host, enabled, *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    *(nickname ? tag("NickName", nickname) : []),
                    *(account ? tag("Account", account) : []),
                    *(auth ? tag("Auth", auth) : []),
                    *(host ? tag("Host", host) : []),
                    *(enabled ? tag("Enabled", enabled) : []))
    end
    
    # ================================================================
    # TIME FEATURE

    # 1. Command: GET_TIME
    def self.get_time(refresh = nil, *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    *(refresh ? tag("Refresh", refresh) : []))
    end
    
    # ================================================================
    # MESSAGE_FEATURE

    # 1. Command: GET_MESSAGE
    def self.get_message(id, *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    tag("Id", sprintf("0x%Xid", id)))
    end
    
    # 3. Command: CONFIRM_MESSAGE
    def self.confirm_message(id, *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    tag("Id", sprintf("0x%Xid", id)))
    end
    
    # ================================================================
    # PRICE FEATURE

    # 1. Command: GET_CURRENT_PRICE
    def self.get_current_price(refresh = nil, *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    *(refresh ? tag("Refresh", refresh) : []))
    end
    
    # 2. Command: SET_CURRENT_PRICE
    def self.set_current_price(price, trailing_digits, *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    tag("Price", sprintf("0x%X", price)),
                    tag("TrailingDigits", sprintf("0x%X", trailing_digits)))
    end
    
    # ================================================================
    # SIMPLE METERING FEATURE

    # 1. Command: GET_INSTANTANEOUS_DEMAND
    def self.get_instantaneous_demand(refresh = nil, *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    *(refresh ? tag("Refresh", refresh) : []))
    end

    # 3. Command: GET_CURRENT_SUMMATION_DELIVERED
    def self.get_current_summation_delivered(refresh = nil, *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    *(refresh ? tag("Refresh", refresh) : []))
    end
    
    # 5. Command: GET_CURRENT_PERIOD_USAGE
    def self.get_current_period_usage(*meter_ids)
      named_command(__method__, 
                    *(meter_ids(meter_ids)))
    end

    # 7. Command: GET_LAST_PERIOD_USAGE
    def self.get_last_period_usage(*meter_ids)
      named_command(__method__, 
                    *(meter_ids(meter_ids)))
    end

    # 9. Command: CLOSE_CURRENT_PERIOD
    def self.close_current_period(*meter_ids)
      named_command(__method__, 
                    *(meter_ids(meter_ids)))
    end
    
    # 10. Command: SET_FAST_POLL
    def self.set_fast_poll(frequency, duration, *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    tag("Frequency", sprintf("0x%X", frequency)),
                    tag("Duration", sprintf("0x%X", duration)))
    end
                    
    # 11. Command: GET_PROFILE_DATA
    def self.get_profile_data(number_of_periods, 
                              end_time, 
                              interval_channel, 
                              *meter_ids)
      named_command(__method__,
                    *(meter_ids(meter_ids)),
                    tag("NumberOfPeriods", sprintf("0x%X", number_of_periods)),
                    tag("EndTime", sprintf("0x%X", end_time)),
                    tag("IntervalChannel", interval_channel))
    end
                    
private
    
    def self.meter_ids(ids)
      ids.map {|id| tag("MeterMacId", id)}
    end

    def self.named_command(name, *args)
      tag("Command", tag("Name", name), *args)
    end

    def self.tag(tag_name, *children)
      if children.size > 0
        "<#{tag_name}>#{children.join("")}</#{tag_name}>"
      else
        "<#{tag_name} />"
      end
    end

  end
    
end
