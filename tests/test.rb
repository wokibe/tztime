require_relative '../lib/tztime'

tz_time = TzTime.new

#p tz_time.zones.size
#p "rules_dst_on"
#p tz_time.rules_dst_on
#p "rules_dst_off"
#p tz_time.rules_dst_off

#p tz_time.zone_names
#p tz_time.zone_names(/Europe/)
#p tz_time.zone_names(/Tokyo/)

p tz_time.offset("Asia/Tokyo")
p tz_time.offset("Asia/Kolkata")
p tz_time.offset("America/Toronto")
p tz_time.offset("Asia/Hebron")