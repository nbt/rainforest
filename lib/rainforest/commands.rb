module Rainforest

  # ================================================================
  # A set of function calls that generate XML recognized by the
  # EMU-2.
  #
  # TODO: switch to hash-style argument passing with sensible
  # defaults.

  class Commands

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
