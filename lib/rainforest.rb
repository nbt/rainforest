require 'serialport'

module Rainforest

  # ================================================================
  # A simple speaker / listener model: self.broadcast(msg) will cause
  # all listeners to receive rcvr.receive(msg)
  #
  module Broadcaster
    require 'set'

    def broadcast(msg)
      listeners.each {|listener| listener.receive(msg)}
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
  class USBIO
    include Broadcaster
    
    BAUD_RATE = 115200
    DATA_BITS = 8
    STOP_BITS = 1
    PARITY = SerialPort::NONE

    # TODO: dynamic discovery of port.
    DEFAULT_PORTNAME = "/dev/tty.usbserial"

    def initialize(portname = DEFAULT_PORTNAME)
      @portname = portname
    end
    
    def start
      @port = SerialPort.open(@portname, BAUD_RATE, DATA_BITS, STOP_BITS, PARITY)
      @reader_thread = Thread.new do 
        begin
          reader_thread
        ensure
          @port.close
        end
      end
    end
    
    def stop
      @reader_thread = nil
    end
    
    def reader_thread
      $stderr.puts("=== entering reader thread with #{Thread.current}")
      thread = @reader_thread
      begin
        while (thread == @reader_thread)
          broadcast(@port.readline.chomp)
        end
      rescue => e
        $stderr.puts(e.inspect)
      end
      $stderr.puts("=== exiting reader thread with #{Thread.current}")
    end
    
    def write(string)
      @port.write(string)
    end
    
  end

  # ================================================================
  # Simulate an EMU-2 device with same semantics as the USBIO device.
  # The only real difference is that it doesn't need the physical
  # USB device.
  class EmuSim
    include Broadcaster

    DEFAULT_PORTNAME = "/dev/tty.usbserial"

    def initialize(portname = DEFAULT_PORTNAME)
      @portname = portname      # isgnored
    end
    
    def start
      @reader_thread = Thread.new do 
        reader_thread
      end
    end
    
    def stop
      @reader_thread = nil
    end
    
    def reader_thread
      $stderr.puts("=== entering reader thread with #{Thread.current}")
      thread = @reader_thread
      begin
        while (thread == @reader_thread)
          xml =<<EOF
<InstantaneousDemand>
  <DeviceMacId>0xd8d5b9000000014b</DeviceMacId>
  <MeterMacId>0x000781000028c07d</MeterMacId>
  <TimeStamp>#{sprintf("0x%x", Time.now.to_i)}</TimeStamp>
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
      rescue => e
        $stderr.puts(e.inspect)
      end
      $stderr.puts("=== exiting reader thread with #{Thread.current}")
    end
    
    def write(string)
      $stderr.puts("=== write #{string}")
    end

  end

  # ================================================================
  # collect lines of text until we have a complete XML fragment
  class Coalescer
    include Broadcaster

    # state 0: ignore input until we see <tag>.  Save tag.
    # state 1: collect input unil we see <\tag>.  Emit saved input, state = 0

    def initialize()
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
  # Output recognized XML fragments as CSV strings
  class CSVFormatter
    include Broadcaster

    require 'nokogiri'

    # Map a tag ("InstantaneousDemand") to a method (:instantaneous_demand)
    TAG_METHODS = Hash.new(:unrecognized)
    TAG_METHODS["InstantaneousDemand"] = :instantaneous_demand

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
      self.broadcast("#{doc.root.name}, #{device_mac_id}, #{meter_mac_id}, #{time_stamp}, #{demand*multiplier}")
    end

  end

  # ================================================================
  # Write create logging file
  class FileLogger
    require 'logger'
    include Broadcaster
    
    def initialize(logname = "log")
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
