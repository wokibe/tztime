# tz_time: calculate the actual time in a remote timezone (with eventual DST)
# kittekat feb/15

require 'date'

class TzTime
  attr_reader :zones, :rules_dst_on, :rules_dst_off 

  # uses two prepared files with zones and rules data to setup hashes
  # source directory
  DATA_DIR = '../../data/'

  # hash descriptions
  ZONE_GMTOFF   = 0
  ZONE_RULE     = ZONE_GMTOFF + 1
  ZONE_FORMAT   = ZONE_RULE + 1
  ZONE_UNTIL    = ZONE_FORMAT + 1

  RULE_FROM     = 0
  RULE_TO       = RULE_FROM + 1
  RULE_TYPE     = RULE_TO + 1
  RULE_IN       = RULE_TYPE + 1
  RULE_ON       = RULE_IN + 1
  RULE_AT       = RULE_ON + 1
  RULE_SAVE     = RULE_AT + 1
  RULE_LETTER   = RULE_SAVE + 1
 
  def initialize
    # prepare the hashes
    path = File.expand_path(DATA_DIR, __FILE__)
    
    # allow named access to the zone info 
    @zones = {}
    File.open(path + '/zones', 'r') do |file|
      file.each_line do |line|
        line.chomp!
        items = line.split
        # hash: key = zone name, value: array of the rest
        @zones[items[0]] = items[1..-1] 
      end
    end # zones
    
    # allow named access to the DST rule infos
    # as there is a change between DST ON and OFF
    # we need two hashes
    @rules_dst_on = {}
    @rules_dst_off = {}
    File.open(path + '/rules', 'r') do |file|
      file.each_line do |line|
        line.chomp!
        items = line.split
        # hash: key = rule name, value: array of the rest
        key = items[0]                  # rule name
        val = items[1..-1]              # slice of the rest
      
        # simplify the format
        val[RULE_SAVE] = "0" if (val[RULE_SAVE] == "0:00") # back to SDT

        # hash: key = rule name, value: array of the rest
        key = items[0]                  # rule name
        val = items[1..-1]              # slice of the rest

        if (val[RULE_SAVE] == "0")
          @rules_dst_off[key] = val
        else
          @rules_dst_on[key] = val
        end 
      end
    end # rules    
  end # initialize
  
  # return array of all zone names
  # show zone name
  def zone_names(filter = //)
    all = @zones.keys.sort
    all.grep(filter)
  end # zone_names
  
  # calculate remote offset, return string <string>hh:mm 
  def offset(zone_name, time = nil)
    time ||= Time.now                 # set default time
    @time = time                      # save as instance variable (for rule())
    @year = @time.year                # dst switches dates are year dependend
    
    offset = zone(zone_name)          # calculate minutes    
    return int2str(offset)            # convert back to hh:mm     
  end
  
  # return string with remote time (including time zone abbreviation)
  def time(zone_name, time = nil)
    puts "to be done"
  end
  
  # return string with remote date/time to switch to DST on
    def dst_on(zone_name, time = nil)
    puts "to be done"
  end
  
  # return string with remote date/time to switch to DST off
    def dst_off(zone_name, time = nil)
    puts "to be done"
  end
  
  # return true if remote is ino DST on
    def dst?(zone_name, time = nil)
    puts "to be done"
  end
  
  private
  
  # handle zone info
  def zone(name)
    if @zones.has_key? name
      puts "offset for %s" % name  
      info = @zones[name]                   
      off_str = info[ZONE_GMTOFF]           # get the zone offset string
      off_minutes = off2int(off_str)        # calculate in minutes  
      dst_offset = rule(info[ZONE_RULE])    # actual eventual DST shift
      return off_minutes + dst_offset       # add them
    else
      puts "Unkown zone_name: %s" % name
      return nil
    end
  end
  
  # handle rule info
  def rule(name)
    if name != '-'
      puts "DST rule %s" % name
      if @rules_dst_on.has_key?(name) and @rules_dst_off.has_key?(name)
        utc_on,  save  = dst(@rules_dst_on[name])  # calculate on switch time
        utc_off, zero = dst(@rules_dst_off[name]) # calculate off switch time
        
        utc = @time.to_i
        # find if we are in the northern or southern hemispere
        if utc_on < utc_off       # northern hemispere
          if (utc >= utc_on) and (utc < utc_off)  # DST active
            dst_offset = save
          else
            dst_offset = zero
          end
        else                      # southern hemispere
          if (utc >= utc_off) and (utc < utc_on)  # DST active
            dst_offset = zero
          else
            dst_offset = save
          end
        end
        return dst_offset 
      else
        puts "Unknown rule_name: %s" % name
        return 0
      end
    else
      return 0
    end
  end
  
  # handle DST info, return switch time (utc seconds) and DTS save
  def dst(rec)
    # get Month index
    mon = Date::ABBR_MONTHNAMES.rindex(rec[RULE_IN])
    unless mon.nil?
      # calculate day
      on_str = rec[RULE_ON]
      day = on_day(mon, on_str)
      unless day.nil?
        at_str = rec[RULE_AT]
        puts "at_str: %s" % at_str
        hh, mm, modifier = at2int(at_str)
        puts "at: hh = %i, mm= %i, modifier = %s" % [hh, mm, modifier]
        utc = Time.new(@year,  mon, day).to_i
        if rec[RULE_SAVE] == "0"
          dst_save = 0
        else
          dst_save = off2int(rec[RULE_SAVE])
        end
        puts "dst_save: %s" % dst_save
        if (modifier == 'w') or (modifier == '')
          utc = utc + dst_save*60          #switch at wall time
        end
        puts "adjusted switchtime: %s" % Time.at(utc)
        return utc, dst_save
      else    
        puts "invalid rule[RULE_AT]: %s" % on_str
        return 0, 0
      end
    else
      puts "invalid rule[RULE_IN]: %s" % rec[RULE_IN]
      return 0, 0
    end
  end
  
  # calculate dst switch day of rule
  def on_day(mon, on_str)
    ml = /last/.match(on_str)
    unless ml.nil?                # format: last<abbr_weekday>
      day_str = ml.post_match
      day_idx = Date::ABBR_DAYNAMES.rindex(day_str)
      unless day_idx.nil?
        day = day_last(mon, day_idx)
        return day
      else
        puts "invalid weekday abbr: %s" % day_str
        return nil
      end
    end
    
    mr = />=/.match(on_str)
    unless mr.nil?                # format: <abbr_weekday>'>='<integer>
      day_str = mr.pre_match
      day_nr = mr.post_match
      day_idx = Date::ABBR_DAYNAMES.rindex(day_str)
      unless day_idx.nil?
        day = day_adj(mon, day_idx, day_nr.to_i)
      else
        puts "invalid weekday abbr: %s" % day_str
        return nil
      end
    end
    
    mi = /\d+/.match(on_str)
    unless mi.nil?                #format <integer>
      day = mi.to_s.to_i
      return day
    else
      return nil
    end
  end
  
  # calculate "last" at_format
  def day_last(mon, day_idx)
    lst = Date.new(@year, mon, -1)      # generate a test day at ultiomo
    day_nr = lst.day
    wday = lst.wday
    diff = day_idx - wday
    unless diff == 0
      day_nr += diff - 7
    end
    return day_nr
  end
  
  # calculate ">=" at_format
  def day_adj(mon, day_idx, day_nr)
    day = Date.new(@year, mon, day_nr)   # generate a test day at the limit
    wday = day.wday
    diff = day_idx - wday
    unless diff == 0
      day_nr += 7 - diff 
    end
    return day_nr
  end
  
  # convert <sign>hh:mm to minutes
  def off2int(str)
    md = /\d+:\d+/.match(str)
    unless md.nil?
      sign = md.pre_match
      of = md.to_s
      os = /:/.match(of)
      unless os.nil?
        hr = os.pre_match
        mn = os.post_match
        result = hr.to_i * 60 + mn.to_i
        result *= -1  if sign == '-'
        return result
      else
        puts "unexpected offset string: %s" % str  
        return 0
      end
    else
      puts "unexpected offset string: %s" % str  
      return 0
    end
  end
  
  # convert hh:mm<modifier> to houres and minutes as integers
  def at2int(str)
    md = /\d+:\d+/.match(str)
    unless md.nil?
      modifier = md.post_match
      of = md.to_s
      os = /:/.match(of)
      unless os.nil?
        hh = os.pre_match.to_i
        mm = os.post_match.to_i
        return hh, mm, modifier
      else
        puts "unexpected offset string: %s" % str  
        return nil
      end
    else
      puts "unexpected offset string: %s" % str  
      return nil
    end
  end
  
  # convert minutes integer to <sign>hh:mm
  def int2str(minutes)
    if minutes < 0
      sign = '-'
      minutes *= -1
    else
      sign = '+' 
    end
    hh = minutes / 60
    mm = minutes % 60
    sprintf("%s%02d:%02d", sign, hh, mm)
  end
  
end # class