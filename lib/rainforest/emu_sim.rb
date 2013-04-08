module Rainforest

  # ================================================================
  # Simulate an EMU-2 device with same semantics as the USBIO device.
  # The only real difference is that it doesn't need the physical
  # USB device.
  class EmuSim < ReaderProcess
    include Speaker
    include Listener

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

    def listen(string)
      $stderr.puts("=== write #{string}")
    end

  end

end
