require 'serialport'

module Rainforest

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
  class USBIO < ReaderProcess
    include Speaker
    include Listener

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
    
    # Anything received as a Listener is written verbatim to the port.
    def listen(string)
      @port.write(string)
    end
    
  end

end
