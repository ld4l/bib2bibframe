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
  :logging => 'file, stdout',
  :prettyprint => false,
}

conf = CONVERTER_DEFAULTS

# Default config file
conf_file = File.join(File.dirname(__FILE__), 'conf', 'conf.yml')

# Parse options
options = {}
OptionParser.new do |opts|

  opts.banner = 'Usage: bib2bibframe [options]'

  opts.on('--baseuri', '=[OPTIONAL]', String, 'Namespace for minting URIs. Overrides configuration setting.') do |arg|
    options[:baseuri] = arg
  end 

  opts.on('--batch', '=[OPTIONAL]', String, 'If true, converts all records together to a single file, rather than separately to individual files. Overrides configuration setting. Defaults to false. Applies only to bibid input.') do
    options[:batch] = true
  end  
    
  opts.on('--catalog', '=[OPTIONAL]', String, 'Library catalog from which to retrieve records. Overrides configuration setting.') do |arg|
    options[:catalog] = arg
  end

  opts.on('--conf', '=[OPTIONAL]', String, 'Configuration file path (directory and filename). Defaults to conf/conf.yml relative to this script.') do |arg|
    conf_file = arg
  end
  
  opts.on('--datadir', '=[OPTIONAL]', String, 'Directory for storing data files. Overrides configuration setting. Defaults to data subdirectory of current directory.') do |arg|
    options[:datadir] = arg
  end 
  
  opts.on('--format', '=[OPTIONAL]', String, 'RDF serialization. Overrides configuration setting. Options: rdfxml, rdfxml-raw, ntriples, json. Defaults to rdfxml.') do |arg|
    options[:format] = arg
  end   
  
  opts.on('--input', '=[OPTIONAL]', String, 'Input. Options are: (1) Comma-separated list of bib ids. (2) The string "bibids:" followed by the absolute path to a file containing a newline-delimited list of bib ids; the file may contain comment lines prefixed with #. (3) The string "marc:" followed by the absolute path to a single MARC file or a directory of MARC files (extension ".mrc"). (4) The string "marcxml:" followed by the absolute path to a single MARCXML file or a directory of MARCXML files (extension ".xml").') do |arg|
    options[:input] = arg
  end

  opts.on('--logdir', '=[OPTIONAL]', String, 'Directory for storing log files. Overrides configuration setting. Defaults to log subdirectory of current directory.') do |arg|
    options[:logdir] = arg
  end  

  opts.on('--logging', '=[OPTIONAL]', String, 'Logging options: off, file, stdout, or both file and stdout.') do |arg|
    options[:logging] = arg
  end  
  
  opts.on('--prettyprint', '=[OPTIONAL]', String, 'Pretty-print the output. Overrides configuration setting. Defaults to log subdirectory of current directory.') do |arg|
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

input = conf.delete(:input)

# Input is a file of bibids
if input.start_with?('bibids:') 
  # TODO If file doesn't exist, either log and exit, or throw an error
  file = File.new input[7..-1]
  bibids = []
  file.each do |line| 
    # Ignore comments and blank lines
    line.chomp!
    next if line.empty? || line[0] == '#'
    bibids << line
  end
  conf[:bibids] = bibids
 
# Input is a path to a MARCXML file or directory of files
elsif input.start_with?('marcxml:')
  conf[:marcxml] = input[8..-1]

# Input is a path to a MARC file or directory of files 
# TODO Add support for MARC input
elsif input.start_with?('marc:')
  # conf[:marc] = input[5..-1]
  puts "MARC input currently not supported"
  exit
  # TODO If file doesn't exist, either log and exit, or throw an error
  # source = File.new input[5..-1]
  # if File.file? source
    # sourcefiles = [ source ]
  # else 
    # sourcefiles = Dir.glob(File.join(source, "*.mrc"))
  # end
  # conf[:marc] = sourcefiles  
  
# Input is a comma-separated list of bibids 
else 
  conf[:bibids] = input.split(%r{,\s*})
end
        
# TODO If no bibids or source specified, or no catalog: either throw an error
# or log an error and exit.


# Convert logging option from string to array
logging = conf.delete(:logging).split(%r{,\s*})
log_destination = {}
if logging.include? 'file'
  log_destination[:dir] = conf[:logdir]
end
log_destination[:stdout] = (logging.include? 'stdout') ? true : false
conf.delete(:logdir)
conf[:log_destination] = log_destination


# Debugging
# conf.each { |k,v| puts "#{k}: #{v}" }

converter = Converter.new(conf)
converter.convert





