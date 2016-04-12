#!/usr/bin/ruby -w

# Convert Cornell bib ids, marc, or marcxml to bibframe rdf (marc not yet
# supported)

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
  :marc2bibframe => File.join('Users', 'rjy7', 'Workspace', 'bib2bibframe', 'lib', 'marc2bibframe'),
  :prettyprint => false,
  :usebnodes => false,
  :verbose => false,
  :xquery => 'saxon'
}


conf = CONVERTER_DEFAULTS

# Default config file
conf_file = File.join(Dir.pwd, 'conf', 'conf.yml')

# Parse options
options = {}
OptionParser.new do |opts|

  opts.banner = 'Usage: bib2bibframe.rb [options]'

  opts.on('--baseuri', '=[OPTIONAL]', String, 'Namespace for minting URIs. Overrides configuration setting.') do |arg|
    options[:baseuri] = arg
  end 

  opts.on('--batch', '=[OPTIONAL]', String, 'If true, converts all records together to a single file, rather than separately to individual files. Overrides configuration setting. Defaults to false. Applies only to bibid input.') do
    options[:batch] = true
  end  
    
  opts.on('--catalog', '=[OPTIONAL]', String, 'Library catalog from which to retrieve records. Overrides configuration setting.') do |arg|
    options[:catalog] = arg
  end

  opts.on('--conf', '=[OPTIONAL]', String, 'Absolute or relative path to configuration file. Defaults to conf/conf.yml in current working directory.') do |arg|
    conf_file = arg
  end
    
  opts.on('--datadir', '=[OPTIONAL]', String, 'Absolute or relative path to directory for storing data files. Overrides configuration setting. Defaults to data subdirectory of current directory.') do |arg|
    options[:datadir] = arg
  end 
  
  opts.on('--format', '=[OPTIONAL]', String, 'RDF serialization. Overrides configuration setting. Options: rdfxml, rdfxml-raw, ntriples, json. Defaults to rdfxml.') do |arg|
    options[:format] = arg
  end   
  
  opts.on('--input', '=[OPTIONAL]', String, 'Input. Options are: (1) The string "bibids:" followed by a comma-separated list of bib ids. (2) The string "bibid-file:" followed by the absolute or relative path to a file containing a newline-delimited list of bib ids; the file may contain comment lines prefixed with #. (3) The string "marc:" followed by the absolute or relative path to a single MARC file or a directory of MARC files (extension ".mrc"). (4) The string "marcxml:" followed by the absolute or relative path to a single MARCXML file or a directory of MARCXML files (extension ".xml").') do |arg|
    options[:input] = arg
  end

  opts.on('--logdir', '=[OPTIONAL]', String, 'Absolute or relative path of directory for storing log files. Overrides configuration setting. Defaults to log subdirectory of current directory.') do |arg|
    options[:logdir] = arg
  end  

  opts.on('--logging', '=[OPTIONAL]', String, 'Logging options: off, file, stdout, or both file and stdout. Overrides configuration setting. Defaults to both file and stdout.') do |arg|
    options[:logging] = arg
  end  
 
  opts.on('--marc2bibframe', '=[OPTIONAL]', String, 'Absolute or relative path to marc2bibframe converter. Defaults to lib/marc2bibframe in the application directory.') do |arg|
    options[:marc2bibframe] = arg
  end
   
  opts.on('--prettyprint', '=[OPTIONAL]', String, 'Pretty-print the marcxml output. Overrides configuration setting. Defaults to false.') do |arg|
    options[:prettyprint] = arg
  end

  # TODO Check to see if this is really what usebnodes does
  opts.on('--usebnodes', '=[OPTIONAL]', String, 'Passed as argument to converter, specifying whether to generate bnodes in conversion. Values are true or false. Defaults to false.') do |arg|
    options[:usebnodes] = arg
  end
  
  opts.on('--verbose', '=[OPTIONAL]', String, 'Verbose logging. Verbose messages are logged only to console, not to log file. Overrides configuration setting. Defaults to false.') do |arg|
    options[:verbose] = arg
  end

  opts.on('--xquery', '=[OPTIONAL]', String, 'XQuery processor. Options are saxon, or an absolute or relative path to the zorba processor. Overrides configuration setting. Defaults to saxon.') do |arg|
    options[:xquery] = arg
  end
  
  opts.on_tail('-h', '--help', 'Show this message') do
    # TODO Improve output formatting: http://optionparser.rubyforge.org/. Is
    # this still valid? Can't find class Option.
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

if ! conf[:input] 
  puts "ERROR: missing input value. Exiting."
  exit
end

values = conf.delete(:input).partition ":"
keys = [:type, :sep, :value]
input = Hash[keys.zip values]

case input[:type]
when "bibids"
  conf[:bibids] = input[:value].split(%r{,\s*})
  
when "bibid-file"
  # TODO If file doesn't exist, either log and exit, or throw an error
  file = File.new input[:value]
  bibids = []
  file.each do |line| 
    # puts "bibid = #{line}"
    # Ignore comments and blank lines
    line.chomp!
    next if line.empty? || line[0] == '#'
    bibids << line
  end
  conf[:bibids] = bibids
 
when "marcxml"
  # TODO If file doesn't exist, either log and exit, or throw an error
  conf[:marcxml] = input[:value]

when "marc"
  # Input is a path to a MARC file or directory of files 
  # TODO Add support for MARC input
  # conf[:marc] = input[:value]
  puts "MARC input currently not supported. Exiting."
  exit

else
  puts "ERROR: invalid input value. Exiting."
  exit
end

# Convert logging options to an array
log_destination = {:stdout => false, :dir => nil}

# Yaml converts 'off' to false; don't call split() on false
if conf[:logging] 
  logging = conf[:logging].split(%r{,\s*})
  if logging.include? 'file'
    log_destination[:dir] = conf[:logdir]
  end 
  if logging.include? 'stdout'
    log_destination[:stdout] = true
  end 
end

conf[:log_destination] = log_destination

# Clean up unneeded conf values
conf.delete(:logging)
conf.delete(:logdir)

# Verbose logging is only to stdout, so add it only if log destinations include
# stdout
conf[:verbose] = 
  conf[:log_destination][:stdout] && conf[:verbose] ? true : false

# Add to conf so can be logged
conf[:conf_file] = File.join(Dir.pwd, conf_file)

# Debugging
# conf.each { |k,v| puts "#{k}: #{v}" }

converter = Converter.new(conf)
converter.convert

