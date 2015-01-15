#!/usr/bin/ruby -w

# Convert a comma-separated list of Cornell bib ids to Bibframe RDF

require_relative 'converter'
require 'optparse'
require 'yaml'
  
# Default values, if not specified in config file or on commandline. (Not all
# options have defaults - e.g., bibids and catalog.
DEFAULTS = {
  # Serializations supported by bibframe converter: 
  # rdfxml: (default) flattened RDF/XML, everything has an identifier
  # rdfxml-raw: verbose, cascaded output
  # ntriples, json, exhibitJSON
  :format => 'rdfxml',  
  :batch => false,
  :datadir => File.join(Dir.pwd, 'data'),
  :logdir => File.join(Dir.pwd, 'log'),
}

config = YAML.load_file(File.join(Dir.pwd, 'conf.yml'))

# Commandline values will overwrite the defaults.
options = DEFAULTS

# Parse options
OptionParser.new do |opts|

  opts.banner = 'Usage: bib2bibframe [options]'

  opts.on('--ids', '=MANDATORY', String, 'Comma-separated list of bib ids OR the string "file:" followed by the path to a file containing a newline-delimited list of bib ids.') do |arg|
    if arg.start_with?('file:')
      file = File.new arg[5..-1]
      ids = []
      file.each { |line| ids << line.chomp }
    else
      ids = arg.split(',')
    end
    options[:bibids] = ids 
  end  

  opts.on('--catalog', '=[OPTIONAL]', String, 'Library catalog from which to retrieve; overrides configuration setting.') do |arg|
    options[:catalog] = arg
  end
     
  opts.on('--baseuri', '=[OPTIONAL]', String, 'Namespace for minting URIs; overrides configuration setting.') do |arg|
    options[:baseuri] = arg
  end 

  opts.on('--format', '=[OPTIONAL]', String, 'RDF serialization; overrides configuration setting. Options: rdfxml, rdfxml-raw, ntriples, json. Defaults to rdfxml.') do |arg|
    options[:format] = arg
  end   
  
  opts.on('--batch', '', nil, 'Convert all records together to a single file, rather than separately to individual files.') do
    options[:batch] = true
  end  
   
  opts.on('--datadir', '=[OPTIONAL]', String, 'Directory for storing data files; overrides configuration setting; defaults to ./data.') do |arg|
    options[:datadir] = arg
  end  

  opts.on('--logdir', '=[OPTIONAL]', String, 'Directory for storing log files; overrides configuration setting; defaults to ./log.') do |arg|
    options[:logdir] = arg
  end  
  
  opts.on_tail('-h', '--help', 'Show this message') do
    puts opts
    exit
  end
  
end.parse!
  
# Commandline arguments take precedence over config settings.
config.merge! options

# Symbolize keys
config = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

# config.each { |k,v| puts "#{k}: #{v}" }

converter = Converter.new(config)
converter.convert
converter.log




