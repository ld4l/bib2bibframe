#!/usr/bin/ruby -w

# Convert Cornell bib ids, marc, or marcxml to bibframe rdf (marc not yet
# supported)

require_relative 'converter'
require_relative 'logger'
require 'optparse'
require 'yaml'

start_time = Time.now

# Default converter config values, if not specified in config file or on 
# commandline. (Not all settings have defaults - e.g., bibids and catalog.)
CONVERTER_DEFAULTS = {
  :batch => false,
  :outdir => File.join(Dir.pwd, 'data'),
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
    
  opts.on('--outdir', '=[OPTIONAL]', String, 'Absolute or relative path to directory for storing data files. Overrides configuration setting. Defaults to data subdirectory of current directory.') do |arg|
    options[:outdir] = arg
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

# conf.each { |k,v| puts "#{k}: #{v}" }

# Create logger
log_conf = Hash.new
array = [:logdir, :logging, :verbose]
array.each { |key| log_conf[key] = conf.delete(key) }
log_conf[:start_time] = start_time
# log_conf.each { |k,v| puts "#{k}: #{v}" }
logger = Logger.new(log_conf)

if ! conf[:input] 
  log_error "ERROR: missing input value. Exiting."
  exit
end

conf[:outdir] = File.join(conf[:outdir], logger.formatted_start_time) 

log_destinations = logger.log_destinations
start_log = [
  'Start conversion at ' + logger.formatted_datetime(start_time),
  'Using config file: ' + conf_file,
  'Selected configuration (from commandline options, conf file, defaults):',     
  'Log file: ' + log_destinations[:file],
  'Log to stdout: ' + (log_destinations[:stdout] ? 'yes' : 'no'),
  'Input: ' + conf[:input],
  'Output directory: ' + conf[:outdir],
  'Base URI: ' + conf[:baseuri],
  'Catalog: ' + conf[:catalog],
  'marc2bibframe converter: ' + conf[:marc2bibframe],
  'XQuery processor: ' + conf[:xquery],
  'RDF format: ' + conf[:format],
  'Use blank nodes: ' + (conf[:usebnodes] ? 'yes' : 'no'),
  'Batch processing: ' + (conf[:batch] ? 'yes' : 'no'),
  'Verbose logging to stdout: ' + (logger.verbose? ? 'on' : 'off')
]  

logger.log start_log

conf[:logger] = logger
 
input = {}

if conf[:input].include? ":"
  input_values = conf_input.split ":"
  input[:type] = input_values[0]
  input[:value] = input_values[1]
else 
  input[:type] ='bibids'
  input[:value] = conf[:input]
end

conf.delete :input

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
  logger.log_error "MARC input currently not supported. Exiting."
  exit

else
  logger.log_error "ERROR: invalid input value. Exiting."
  exit
end


# Debugging
# conf.each { |k,v| puts "#{k}: #{v}" }

converter = Converter.new(conf)
converter.convert

end_time = Time.now
end_time = Time.now
duration = end_time - start_time

logger.log [
  "End conversion: " + logger.formatted_datetime(end_time),
  "Processing time: " + logger.seconds_to_time(duration)
]
