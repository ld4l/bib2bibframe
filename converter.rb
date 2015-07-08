require 'fileutils'
require_relative 'preprocessor'

class Converter

  FILE_EXTENSIONS = {
    'marc' => '.mrc',
    'marcxml' => '.xml',
    'rdfxml' => '.rdf',
    'rdfxml-raw' => '.rdf',
    'json' => '.js',
    'ntriples' => '.nt',
    # 'turtle' => '.ttl',
  }

  # Set variables and create directories common to all bibids in the conversion
  # request
  def initialize config
    
    # Initialize instance variables that are optional config hash
    @bibids = ''
    @marcxml = ''
    # @marc = ''
    @saxon = ''
    @zorba = ''
    
    config.each {|k,v| instance_variable_set("@#{k}",v)} 
    
    lib = File.join(File.dirname(__FILE__), 'lib')
    xbin = File.join(lib, 'marc2bibframe', 'xbin')
    if @xquery == 'saxon'
      @saxon = File.join(lib,'saxon951', 'saxon9he.jar')
      @xqy = File.join(xbin, 'saxon.xqy') 
    else 
      @zorba = @xquery
      @xquery = 'zorba'
      @xqy = File.join(xbin, 'zorba.xqy')  
    end
    
    @results = {
      :ids_converted => [],
      :ids_not_found => [],
      :file_count => 0,
    }  
    
    # Non-rdfxml formats require this additional parameter to the LC converter
    @method = (@format == 'ntriples' || @format == 'json') ? "!method=text" : ''
    
    # @preprocessor = Preprocessor.new 
    
  end

  def convert  
 
    datetime_format = '%Y-%m-%d %T%z'
        
    start_time = Time.now
 
    # Create log and data directories
    create_directories start_time.strftime('%Y-%m-%d-%H%M%S')
    
    log "Start conversion: " + start_time.strftime(datetime_format)
    log "XQuery processor: " + @xquery + '.'
    log "RDF format: " + @format + '.'
        
    if ! @bibids.empty?
      # For now, batch vs single only supported for bibid input
      convert_bibids
    elsif ! @marcxml.empty?      
      # TODO If file doesn't exist, either log and exit, or throw an error
      convert_marcxml
      # TODO Add support for MARC input
    # elseif @marc
      # convert_marc
    end  

    end_time = Time.now
    duration = end_time - start_time

    log "End conversion: " + end_time.strftime(datetime_format) + 
      "\nProcessing time: " + seconds_to_time(duration)
      
    log_results
      
  end

    
  private

    def create_directories datetime
       
      # Create log directory 
      logdir = @log_destination[:dir]
      if logdir       
          FileUtils.makedirs logdir
          @log_destination[:file] = File.join(logdir, datetime + '.log')
          log "Log file location: #{@log_destination[:file]}."
      end
      
      # Create data directories
      @datadir = File.join(@datadir, datetime) 

      if (! File.directory?(@datadir) )
        FileUtils.makedirs @datadir
        log "Created data directory #{@datadir}."
      end
        
      # If input is marcxml, don't need a directory to store generated marcxml.
      if @marcxml.empty?
        @xmldir = File.join(@datadir, 'marcxml') 
        FileUtils.makedirs @xmldir unless File.directory? @xmldir
      end
      
      # @rdfdir = File.join(@datadir, 'bibframe', @xquery, @format)
      @rdfdir = File.join(@datadir, "bibframe-#{@xquery}-#{@format}")
      FileUtils.makedirs @rdfdir unless File.directory? @rdfdir
    end
    
    def convert_marcxml
      
      # @marcxml is a directory name
      if FileTest.directory? @marcxml
        Dir.foreach(@marcxml) do |filename|  
            marcxml_file_to_bibframe File.join(@marcxml, filename)
          end
      # @marcxml is a filename
      # TODO Handle other possibilities - e.g., no file or directory exists
      else 
        marcxml_file_to_bibframe @marcxml
      end    
    end
    
    def marcxml_file_to_bibframe xmlfilename
      # TODO Extension doesn't guarantee mime type: use shell command 
      # "file --mime-type <filename>" to check mime type.
      if xmlfilename.end_with? ".xml" 
        marcxml_to_bibframe File.absolute_path(xmlfilename)
        @results[:file_count] += 1
      end
    end
      
    def convert_marc
      # TODO Add support for marc input files/directory
    end

    def convert_bibids
      # Batch vs single mode applies only to bibid input, for now. 
      @batch ? convert_bibids_batch : convert_bibids_singles
    end
    
    def convert_bibids_singles
      @bibids.each do |id|
        xmlfilename = bibid_to_marcxml id  
        if xmlfilename && ! xmlfilename.empty?   
          marcxml_to_bibframe xmlfilename
        end
      end
    end
    
    def convert_bibids_batch
      xmlfilename = bibids_to_marcxml
      if xmlfilename
        marcxml_to_bibframe xmlfilename  
      end
    end
    
    def bibids_to_marcxml 
      marcxml = ''

      # Concatenate the marcxml for each id
      @bibids.each do |id|
        marcxml << get_marcxml(id)
      end
          
      if ! marcxml.empty?
        marcxml = marcxml_records_to_collection marcxml  
        xmlfilename = write_marcxml marcxml, 'batch' 
      end

      xmlfilename 
    end
    
    # Write marcxml to file
    def write_marcxml marcxml, basename
      xmlfilename = File.join(@xmldir, basename + FILE_EXTENSIONS['marcxml'])
      File.open(xmlfilename, 'w') { |file| file.write marcxml }    
      xmlfilename
    end
    
    def get_marcxml id

      # Retrieve the marcxml from the catalog.
      marcxml_url = File.join(@catalog, id + '.marcxml')  
      
      # TODO Rewrite using curb gem - add to Gemfile    
      marcxml = `curl -s #{marcxml_url}`
      
      if (! marcxml.start_with?("<record"))
        @results[:ids_not_found] << id
        return ''
      end
  
      @results[:ids_converted] << id    
      
      # Pretty print the unformatted marcxml for display purposes. The marcxml
      # contains only single quotes, so passing it to echo in double quotes 
      # works.
      if @prettyprint
        marcxml = `echo "#{marcxml}" | xmllint --format -`
      end
      
      marcxml
    end
    
    def marcxml_records_to_collection marcxml
    
      # Wrap in <collection> tag. Doesn't make any difference in the bibframe of 
      # a single record, but is needed to process multiple records into a single 
      # file, so just add it generally.
      marcxml = marcxml.gsub(/<\?xml version=['"]1.0['"]\?>/, '')
      marcxml = marcxml.gsub(/<record xmlns=['"]http:\/\/www.loc.gov\/MARC21\/slim['"]>/, '<record>')
      marcxml = 
        "<?xml version='1.0' encoding='UTF-8'?><collection xmlns='http://www.loc.gov/MARC21/slim'>" + marcxml + '</collection>'
  
      # Exceeds xmllint's capacity when large number of records are processed
      # in batch. Apply to individual records instead.
      # Pretty print the unformatted marcxml for display purposes
      # marcxml = `cat #{marcxml} | xmllint --format -` 
    end 
           
    # Get marcxml for the bibid and write to a file
    def bibid_to_marcxml id   
      marcxml = get_marcxml id
      xmlfilename = ''
      if ! marcxml.empty?
        marcxml = marcxml_records_to_collection marcxml
        xmlfilename = write_marcxml marcxml, id   
      end
      xmlfilename
    end

    # Convert marcxml for the id to bibframe rdf and write to file
    
    def marcxml_to_bibframe xmlfilename
      
      # Might be nice to count records in the file for reporting, but may be
      # too time-consuming on large files.

      rdffile = File.join(@rdfdir, File.basename(xmlfilename, FILE_EXTENSIONS['marcxml']) + FILE_EXTENSIONS[@format])
      
      # Preprocess the xml
      # @preprocessor.preprocess xmlfilename
                
      if @xquery == 'saxon'
        # Saxon 9.6 removed support for defaults in favor of the XQuery 3.0 
        # syntax, so the usebnode value must be specified. Add the parameter so
        # we can use either Saxon 9.5 or 9.6.    
        command = "java -cp #{@saxon} net.sf.saxon.Query #{@method} #{@xqy} marcxmluri=#{xmlfilename} baseuri=#{@baseuri} serialization=#{@format} usebnodes=false" 
   
        # Not needed because converter already pretty-prints the rdf. 
        # if @prettyprint and ( @format == 'rdfxml' or @format == 'rdfxml-raw' )
          # # The output from the LC converter contains both single and double 
          # # quotes. It can't be piped from echo to xmllint, because the argument
          # # to echo cannot be wrapped in either single or double quotes. Piping
          # # the converter output directly to xmllint works, since it doesn't have
          # # to be stored in a variable.
          # command += " | xmllint --format -"
        # end
   
      else
        command = "#{@zorba} -i -f -q #{@xqy} -e marcxmluri:=#{xmlfilename} -e serialization:=#{@format} -e baseuri:=#{@baseuri}"
      end
      
      rdf = `#{command}` 

      File.open(rdffile, 'w') { |file| file.write rdf }   
    end


    def log_results
  
      return if @log_destination.empty?
      
      # Build the log message

      summary = []
      summary << "Results:"

      if ! @bibids.empty?
        totals_log = "#{sg_or_pl('bib id', @bibids.length)} processed."
        
        # For now, not logging individual ids successfully converted. Assumption is that they exist, so only log the number 
        # converted, and individual ids not converted.
        ids_converted_log = sg_or_pl('record', @results[:ids_converted].length) + ' found and converted' + (@batch ? ' in batch ' : ' ') + 'to bibframe.'
                   
        id_not_found_count = @results[:ids_not_found].length       
        ids_not_found_log = "#{sg_or_pl('id', id_not_found_count)} without a bib record"
        if id_not_found_count > 0
          ids_not_found_log << ': ' + @results[:ids_not_found].join(', ')
        end
        ids_not_found_log << '.'  
            
        summary << [ totals_log, ids_converted_log, ids_not_found_log ]
             
      elsif ! @marcxml.empty?
        summary << "#{sg_or_pl('marcxml file', @results[:file_count])} converted to bibframe."
      end
      
      log summary  
    end
    
    
    def log message
 
      # Write the log to a file, if specified
      if @log_destination[:file]
        File.open(@log_destination[:file], 'a') do |f|
          f.puts message
        end
      end
      
      # Write the log to stdout, if specified
      if @log_destination[:stdout]
        puts message
      end 
    end
     
       
    def sg_or_pl(string, count)
      count.to_s + ' ' + string + (count == 1 ? '' : 's')
    end
    
    def seconds_to_time(seconds)
      floor = seconds.floor
      h = floor / 3600
      m = floor / 60 % 60
      s = seconds.round % 60

      # [h, m, s].map { |t| t.to_s.rjust(2, '0')}.join(':')
      sprintf "%02d:%02d:%02d", h, m, s

    end
    
end
