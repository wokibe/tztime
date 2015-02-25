#!/usr/bin/env ruby

# prepare actual zones and rules file for tz_time
# extract the current valid infos from the tzdata database
# kittekat feb/15

# TODO: allow CLI parameters to select the directory of the tzdata files

require 'time'

# list of required tzdata files (unzipped from the IANA zoneinfo distribution)
TZDATA_FILES = 
  %w( europe africa asia australasia northamerica southamerica antarctica) 
# source directory
TZDATA_DIR = '/Users/kittekat/Downloads/timezone/tzdata-latest/'

# destination directory
DATA_DIR = '../../data/'

THIS_YEAR = Time.now.year
 
# record descriptions
REC_TYP       = 0

ZONE_NAME     = 1
ZONE_GMTOFF   = ZONE_NAME + 1
ZONE_RULE     = ZONE_GMTOFF + 1
ZONE_FORMAT   = ZONE_RULE + 1
ZONE_UNTIL    = ZONE_FORMAT + 1      # [year [month [day [hh:mm]]]]

RULE_NAME     = 1
RULE_FROM     = RULE_NAME + 1
RULE_TO       = RULE_FROM + 1
RULE_TYPE     = RULE_TO + 1
RULE_IN       = RULE_TYPE + 1
RULE_ON       = RULE_IN + 1
RULE_AT       = RULE_ON + 1
RULE_SAVE     = RULE_AT + 1
RULE_LETTER   = RULE_SAVE + 1

# add relevant records to the zones file
def add_zone(items, file)
  # TODO: check if termination date is in THIS_YEAR
  unless items.size > ZONE_UNTIL      # unlimited entry
    line = items[1..-1].join(' ')
    file.puts line
  end
end

# add relevant records to the rules file
def add_rule(items, file)
  rule_from = items[RULE_FROM].to_i
  rule_str = items[RULE_TO]
  rule_to = rule_str.to_i
  if  (  
        (rule_from <= THIS_YEAR) and
          ( 
            (rule_to >= THIS_YEAR) or
            (rule_str == 'max')
          ) 
      ) or
      (
        (rule_from == THIS_YEAR) and 
        (rule_str == 'only')
      ) 
    line = items[1..-1].join(' ')
    file.puts line
  end
end

# create the files
path = File.expand_path(DATA_DIR, __FILE__)
zones = File.new(path + '/zones', 'w')
rules = File.new(path + '/rules', 'w')

# loop over the source files
TZDATA_FILES.each do |file_name|      # loop over the required tzdata files
  data_file = TZDATA_DIR + file_name
  puts data_file
  File.open(data_file, 'r') do |file|
    zone_save = ''
    file.each_line do |line|          # loop over this file
      line.chomp!                     # get rid of line speparators
      line.gsub!(/\t/, ' ')           # replace all tabs by spaces
      #puts ">%s" % line
      
      # the zone names are not repeated in successing records
      line.sub!(/^\s/, 'Same zone')   # indicate usage of last seen zone
      
      unless line[0] == '#'           # ignore comment lines
        md = / #/.match(line)            # ignore inline comments
        line = md.pre_match unless md.nil?
      
        items = line.split              # split on whitespaces
        typ = items[REC_TYP]
        unless typ.nil?                 # skip empty lines
          case typ                      # distribute
          when 'Zone' 
            zone_save = items[ZONE_NAME]  # save for "Same zone"
            add_zone(items, zones)
          when 'Rule'
            add_rule(items, rules)
          when 'Same'
            items[ZONE_NAME] = zone_save
            add_zone(items, zones)
          when 'Link' then {}             # ignore links
          else
            unless typ =~ /#+/            # ignore comments
              puts "Unexpected typ: %s" % typ
              puts ">> %s" % line
            end
          end # case  
        end
      end
    end
  end
end
zones.close
rules.close
