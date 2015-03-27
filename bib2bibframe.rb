#!/usr/bin/ruby -w

# Convert a comma-separated list of Cornell bib ids to Bibframe RDF

require_relative 'converter'
require 'optparse'
require 'yaml'
  
# Default converter config values, if not specified in config file or on 
# commandline. (Not all settings have defaults - e.g., bibids and catalog.)
CONVERTER_DEFAULTS = {
  :batch => false,
  :datadir => File.join(Dir.pwd, 'data'),
  # Serializations supported by bibframe converter: 
  # rdfxml: (default) flattened RDF/XML, everything has an identifier
  # rdfxml-raw: verbose, cascaded output
  # ntriples, json, exhibitJSON
  :format => 'rdfxml',  
  :logdir => File.join(Dir.pwd, 'log'),
}

conf = CONVERTER_DEFAULTS

# Default config file
conf_file = File.join(File.dirname(__FILE__), 'conf', 'conf.yml')

# Parse options
options = {}
OptionParser.new do |opts|

  opts.banner = 'Usage: bib2bibframe [options]'

  opts.on('--ids', '=MANDATORY', String, 'Comma-separated list of bib ids OR the string "file:" followed by the path to a file containing a newline-delimited list of bib ids. The file may contain comment lines prefixed with #.') do |arg|
    if arg.start_with?('file:')
      file = File.new arg[5..-1]
      ids = []
      file.each do |line| 
        # Ignore comments and blank lines
        line.chomp!
        next if line.empty? || line[0] == '#'
        ids << line
      end
      # puts ids.inspect
    else
      ids = arg.split(',')
    end
    options[:bibids] = ids 
  end  

  opts.on('--baseuri', '=[OPTIONAL]', String, 'Namespace for minting URIs; overrides configuration setting.') do |arg|
    options[:baseuri] = arg
  end 

  opts.on('--batch', '', nil, 'Converts all records together to a single file, rather than separately to individual files.') do
    options[:batch] = true
  end  
    
  opts.on('--catalog', '=[OPTIONAL]', String, 'Library catalog from which to retrieve; overrides configuration setting.') do |arg|
    options[:catalog] = arg
  end

  opts.on('--conf', '=[OPTIONAL]', String, 'Configuration file path (directory and filename). Defaults to conf/conf.yml relative to this script.') do |arg|
    conf_file = arg
  end
  
  opts.on('--datadir', '=[OPTIONAL]', String, 'Directory for storing data files; overrides configuration setting; defaults to data subdirectory of current directory.') do |arg|
    options[:datadir] = arg
  end 
  
  opts.on('--format', '=[OPTIONAL]', String, 'RDF serialization; overrides configuration setting. Options: rdfxml, rdfxml-raw, ntriples, json. Defaults to rdfxml.') do |arg|
    options[:format] = arg
  end   

  opts.on('--logdir', '=[OPTIONAL]', String, 'Directory for storing log files; overrides configuration setting; defaults to log subdirectory of current directory.') do |arg|
    options[:logdir] = arg
  end  
  
  opts.on_tail('-h', '--help', 'Show this message') do
    puts opts
    exit
  end
  
end.parse!

# Load values from config file and symbolize keys
conf_file_settings =  (YAML.load_file conf_file).inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}   

# Config file values overwrite defaults.
conf.merge! conf_file_settings

# Commandline arguments take precedence.
conf.merge! options

# Debugging
# puts 'conf_file: ' + conf_file
# conf.each { |k,v| puts "#{k}: #{v}" }


converter = Converter.new(conf)
converter.convert
converter.log




