#!/usr/bin/ruby -w

# Convert a comma-separated list of Cornell bib ids to bibframe

require 'optparse'
require 'yaml'


def sg_or_pl(string, count)
  count.to_s + ' ' + string + (count == 1 ? '' : 's')
end


log = []


# Process configuration file
config = YAML.load_file('conf.yml')
if (! File.directory?(config['datadir']))
  Dir.mkdir(config['datadir'])
  log << "Created data directory #{config['datadir']}."
end
if (! File.directory?(config['logdir']))
  Dir.mkdir(config['logdir'])
  log << "Created log directory #{config['logdir']}."
end


# Assign default options
options = {
  # Serializations supported by bibframe converter: 
  # rdfxml: (default) flattened RDF/XML, everything has an identifier
  # rdfxml-raw: verbose, cascaded output
  # ntriples, json, exhibitJSON
  :format => 'rdfxml',
}


# Parse options
OptionParser.new do |opts|

  opts.banner = 'Usage: bib2bibframe [options]'
 
  opts.on('--baseuri', '=[OPTIONAL]', String, 'Namespace for minting URIs; overrides configuration option') do |b|
    options[:baseuri] = b
  end 
  
  opts.on('--format', '=[OPTIONAL]', String, 'RDF serialization; defaults to rdfxml') do |f|
    options[:format] = f
  end  

  opts.on('--ids', '=MANDATORY', String, 'Comma- or newline-separated list of bib ids') do |ids|
    options[:bibids] = ids
  end  
  
  opts.on_tail('-h', '--help', 'Show this message') do
    puts opts
    exit
  end
  
end.parse!


# baseuri option overwrites config setting
baseuri = options.has_key?(:baseuri) ? options[:baseuri] : config['baseuri']


# Create directories to store output
datetime = Time.now.strftime('%Y%m%d-%H%M%S')
datadir = File.join(config['datadir'], datetime)
Dir.mkdir(datadir)
xmldir = File.join(datadir, 'marcxml') 
Dir.mkdir(xmldir)
rdfdir = File.join(datadir, 'bibframe')
Dir.mkdir(rdfdir)

# Allow either comma- or newline-delimited list of bibids 
bibids = options[:bibids].split(%r{,\s*|\n})

# Set bibframe file extension based on serialization
rdfext = '.' +
  case options[:format]
    when 'rdfxml', 'rdfxml-raw'
      'rdf'
    when 'json', 'extendedJSON'
      'json'
    when 'ntriples',
      'nt'
  end
  
    
# Process the conversions
id_count = 0
records = []
no_records = []

bibids.each do |id|

  id_count += 1
  
  # Retrieve the marcxml from the Voyager catalog. Include timestamp.
  marcxml = `curl -s http://newcatalog.library.cornell.edu/catalog/#{id}.marcxml`
  if (! marcxml.start_with?("<record"))
    # log << "WARNING: No record found for bib id #{id}."
    no_records << id
    next
  end

  records << id
  
  # Wrap in <collection> tag. Doesn't make any difference in the bibframe of a
  # single record, but is needed to process multiple records into a single file,
  # so just add it generally.

  marcxml = marcxml.gsub(/<record xmlns='http:\/\/www.loc.gov\/MARC21\/slim'>/,
  "<?xml version='1.0' encoding='UTF-8'?><collection xmlns='http://www.loc.gov/MARC21/slim'>\n
  <record>") 
  marcxml << "</collection>"
  
  # Pretty print the unformatted marcxml for display purposes
  marcxml = `echo "#{marcxml}" | xmllint --format -`
  
  xmlfile = File.join(xmldir, id + '.xml')
  File.write(xmlfile, marcxml)     

  rdffile = File.join(rdfdir, id + rdfext)
    
  saxon = File.join('lib', 'saxon', 'saxon9he.jar')
  xquery = File.join('lib', 'marc2bibframe', 'xbin', 'saxon.xqy') 

  command = "java -cp #{saxon} net.sf.saxon.Query #{xquery} marcxmluri=#{xmlfile} baseuri=#{baseuri} serialization=#{options[:format]} > #{rdffile}"
  system(command)
  
  # TODO - for app - return the marcxml and bibframe to the application 
  # Make a config option, so don't maintain 2 versions of the script?
  
end


# Write the log
totals_log = "#{sg_or_pl('bib id', id_count)} processed."

records_log = "#{sg_or_pl('record', records.length)} found and converted to bibframe"
if records.length > 0
  records_log << ': ' + records.join(', ')
end
records_log << '.'

no_records_log = "#{sg_or_pl('bib id', no_records.length)} without a corresponding bib record"
if no_records.length > 0
  no_records_log << ': ' + no_records.join(', ')
end
no_records_log << '.'

log << [ totals_log, records_log, no_records_log ]

logfile = File.join(config['logdir'], datetime + '.log')
File.open(logfile, 'w') do |file|
  log.each { |line| file.puts line }
end