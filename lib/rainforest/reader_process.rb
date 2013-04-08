module Rainforest

  # ================================================================
  # Abstract class for Speaker with a reader thread
  class ReaderProcess

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

    # normally subclassed
    def reader_body
      sleep(10)
    end

private

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

  end

end
