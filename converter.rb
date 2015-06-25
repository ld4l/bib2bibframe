require 'fileutils'

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
    
    # Initialize instance variables that may not be set in config hash
    @bibids = ''
    @marcxml = ''
    # @marc = ''
    
    config.each {|k,v| instance_variable_set("@#{k}",v)}

    @log = {
      :message => [],
      :records => [],
      :no_records => [],
      :record_count => 0,
    }  
      
    @saxon = File.join(File.dirname(__FILE__), 'lib', 'saxon951', 'saxon9he.jar')

    @xquery = File.join(File.dirname(__FILE__), 'lib', 'marc2bibframe', 'xbin', 'saxon.xqy') 
    
    # Non-rdfxml formats require this additional parameter to the LC converter
    @method = (@format == 'ntriples' || @format == 'json') ? "!method=text" : ''
    
  end

  def convert  
    
    now = Time.now
    datetime_format = '%Y-%m-%d %T%z'
    
    @log[:message] << "Start conversion: " + now.strftime(datetime_format) 
    
    create_directories now.strftime('%Y-%m-%d-%H%M%S')
        
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
     
    @log[:message] << "End conversion: " + Time.now.strftime(datetime_format) 
    
    log
      
  end

 
    
  private

    def create_directories datetime
       
      # Create log directory 
      logdir = @log_destination[:dir]
      if logdir       
          FileUtils.makedirs logdir
          @log[:message] << "Created log directory #{logdir}."
          @log_destination[:file] = File.join(logdir, datetime + '.log')
      end
      
      # Create data directories
      @datadir = File.join(@datadir, datetime) 

      if (! File.directory?(@datadir) )
        FileUtils.makedirs @datadir
        @log[:message] << "Created data directory #{@datadir}."
      end
        
      # If input is marcxml, don't need a directory to store generated marcxml.
      if @marcxml.empty?
        @xmldir = File.join(@datadir, 'marcxml') 
        FileUtils.makedirs @xmldir unless File.directory? @xmldir
      end
      
      @rdfdir = File.join(@datadir, 'bibframe', @format)
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
      # TODO Not a bulletproof way of determining file type
      if xmlfilename.end_with? ".xml"
        marcxml_to_bibframe xmlfilename
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
      marcxml = `curl -s #{marcxml_url}`
      
      if (! marcxml.start_with?("<record"))
        @log[:no_records] << id
        return ''
      end
  
      @log[:records] << id    
      
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
      
      @log[:record_count] += 1
      rdffile = File.join(@rdfdir, File.basename(xmlfilename, FILE_EXTENSIONS['marcxml']) + FILE_EXTENSIONS[@format])
      
      # Saxon 9.6 removed support for defaults in favor of the XQuery 3.0 
      # syntax, so the usebnode value must be specified. Add the parameter so
      # we can use either Saxon 9.5 or 9.6.    
      command = "java -cp #{@saxon} net.sf.saxon.Query #{@method} #{@xquery} marcxmluri=#{xmlfilename} baseuri=#{@baseuri} serialization=#{@format} usebnodes=false" 
 
      # TODO Is there a way to pretty-print other formats?
      if @prettyprint and ( @format == 'rdfxml' or @format == 'rdfxml-raw' )
        # The output from the LC converter contains both single and double 
        # quotes. It can't be piped from echo to xmllint, because the argument
        # to echo cannot be wrapped in either single or double quotes. Piping
        # the converter output directly to xmllint works, since it doesn't have
        # to be stored in a variable.
        command += " | xmllint --format -"
      end
 
      rdf = `#{command}` 
      
      File.open(rdffile, 'w') { |file| file.write rdf }   
    end


    def log
  
      return if @log_destination.empty?
      
      # Build the log message
      
      @log[:message] << 'Results:'
      
      # record_count = @log[:records].length
      record_count = @log[:record_count]
      no_record_count = @log[:no_records].length
  
      if ! @bibids.empty?
        bibid_count = @bibids.length
        totals_log = "#{sg_or_pl('bib id', bibid_count)} processed."
        
        records_log = sg_or_pl('record', record_count) + ' found and converted' + (@batch ? ' in batch ' : ' ') + 'to bibframe'
        # On a large scale we wouldn't want this. Can just inspect the no_records
        # log to determine what was not successfully converted.
        # if @log[:records].length > 0
        #   records_log << ': ' + @log[:records].join(', ')
        # end
        records_log << '.'
        
        no_records_log = "#{sg_or_pl('id', no_record_count)} without a bib record"
        if no_record_count > 0
          no_records_log << ': ' + @log[:no_records].join(', ')
        end
        no_records_log << '.'
        
        @log[:message] << [ totals_log, records_log, no_records_log ]
             
      elsif ! @marcxml.empty?
        totals_log = "#{sg_or_pl('marcxml file', record_count)} converted to bibframe."
        @log[:message] << totals_log
      end
  
      # Write the log to a file, if specified
      if @log_destination[:file]
        File.open(@log_destination[:file], 'w') do |file|
          file.puts @log[:message]
        end
      end
      
      # Write the log to stdout, if specified
      if @log_destination[:stdout]
        puts @log[:message]
      end
  
    end 
       
    def sg_or_pl(string, count)
      count.to_s + ' ' + string + (count == 1 ? '' : 's')
    end

end