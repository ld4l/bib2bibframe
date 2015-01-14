#!/usr/bin/ruby -w

# Convert a comma-separated list of Cornell bib ids to Bibframe RDF

require_relative 'converter'
require 'optparse'
require 'yaml'
  
DEFAULTS = {
  # Serializations supported by bibframe converter: 
  # rdfxml: (default) flattened RDF/XML, everything has an identifier
  # rdfxml-raw: verbose, cascaded output
  # ntriples, json, exhibitJSON
  :format => 'rdfxml',  
  
  # If not specified in config file
  :datadir => File.join(Dir.pwd, 'data'),
  :logdir => File.join(Dir.pwd, 'log'),
}

config = YAML.load_file(File.join(Dir.pwd, 'conf.yml'))

options = DEFAULTS

# Parse options
OptionParser.new do |opts|

  opts.banner = 'Usage: bib2bibframe [options]'
 
  opts.on('--baseuri', '=[OPTIONAL]', String, 'Namespace for minting URIs; overrides configuration option') do |b|
    options[:baseuri] = b
  end 
  
  opts.on('--format', '=[OPTIONAL]', String, 'RDF serialization; defaults to rdfxml') do |f|
    options[:format] = f
  end  

  opts.on('--ids', '=MANDATORY', String, 'Comma-separated list of bib ids') do |ids|
    options[:bibids] = ids.split(',')
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




