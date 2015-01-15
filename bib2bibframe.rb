#!/usr/bin/ruby -w

# Convert a comma-separated list of Cornell bib ids to Bibframe RDF

require_relative 'converter'
require 'optparse'
require 'yaml'
  
# Default values if not specified in config file or on commandline
DEFAULTS = {
  # Serializations supported by bibframe converter: 
  # rdfxml: (default) flattened RDF/XML, everything has an identifier
  # rdfxml-raw: verbose, cascaded output
  # ntriples, json, exhibitJSON
  :format => 'rdfxml',  
  :datadir => File.join(Dir.pwd, 'data'),
  :logdir => File.join(Dir.pwd, 'log'),
}

config = YAML.load_file(File.join(Dir.pwd, 'conf.yml'))

options = DEFAULTS

# Parse options
OptionParser.new do |opts|

  opts.banner = 'Usage: bib2bibframe [options]'

  opts.on('--ids', '=MANDATORY', String, 'Comma-separated list of bib ids.') do |ids|
    options[:bibids] = ids.split(',')
  end  

  opts.on('--catalog', '=[OPTIONAL]', String, 'Library catalog from which to retrieve; overrides configuration setting.') do |f|
    options[:catalog] = f
  end
     
  opts.on('--baseuri', '=[OPTIONAL]', String, 'Namespace for minting URIs; overrides configuration setting.') do |b|
    options[:baseuri] = b
  end 

  opts.on('--format', '=[OPTIONAL]', String, 'RDF serialization; overrides configuration setting. Options: rdfxml, rdfxml-raw, ntriples, json. Defaults to rdfxml.') do |f|
    options[:format] = f
  end   
  
  opts.on('--datadir', '=[OPTIONAL]', String, 'Directory for storing data files; overrides configuration setting; defaults to ./log.') do |f|
    options[:datadir] = f
  end  

  opts.on('--logdir', '=[OPTIONAL]', String, 'Directory for storing log files; overrides configuration setting; defaults to ./log.') do |f|
    options[:logdir] = f
  end  
  
  opts.on_tail('-h', '--help', 'Show this message') do
    puts opts
    exit
  end
  
end.parse!
  
# Commandline options take precedence over default options and config settings.
config.merge! options

# Symbolize keys
config = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

converter = Converter.new(config)
converter.convert
converter.log




