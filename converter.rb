require 'fileutils'

class Converter

  FILE_EXTENSIONS = {
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

    config.each {|k,v| instance_variable_set("@#{k}",v)}

    @log = {
      :message => [],
      :records => [],
      :no_records => [],
    }  
      
    datetime = Time.now.strftime('%Y%m%d-%H%M%S')
    @logfile = File.join(@logdir, datetime + '.log')
    @datadir = File.join(@datadir, datetime)      
    
    @saxon = File.join(File.dirname(__FILE__), 'lib', 'saxon', 'saxon9he.jar')
    @xquery = File.join(File.dirname(__FILE__), 'lib', 'marc2bibframe', 'xbin', 'saxon.xqy') 
    # Non-rdfxml formats require this additional parameter to the LC converter
    @method = (@format == 'ntriples' || @format == 'json') ? "!method=text" : ''
    
    create_data_directories
  end

  def convert  
    @batch ? convert_batch : convert_singles
  end

  # Write the log to file
  def log
      
    totals_log = "#{sg_or_pl('bib id', @bibids.length)} processed."
    
    records_log = sg_or_pl('record', @log[:records].length) + ' found and converted' + (@batch ? ' in batch ' : ' ') + 'to bibframe'
    # On a large scale we wouldn't want this. Can just inspect the no_records
    # log to determine what was not successfully converted.
    # if @log[:records].length > 0
    #   records_log << ': ' + @log[:records].join(', ')
    # end
    records_log << '.'
    
    no_records_log = "#{sg_or_pl('id', @log[:no_records].length)} without a bib record"
    if @log[:no_records].length > 0
      no_records_log << ': ' + @log[:no_records].join(', ')
    end
    no_records_log << '.'
    
    @log[:message] << [ totals_log, records_log, no_records_log ]
    
    if (! File.directory?(@logdir) )
      FileUtils.makedirs @logdir
      @log[:message] << "Created log directory #{@logdir}."
    end
    
    File.open(@logfile, 'w') do |file|
      @log[:message].each do |line| 
        puts line
        file.puts line  
      end
    end 
  end
    
  private

    def create_data_directories

      if (! File.directory?(@datadir) )
        FileUtils.makedirs @datadir
        @log[:message] << "Created data directory #{@datadir}."
      end
        
      @xmldir = File.join(@datadir, 'marcxml') 
      FileUtils.makedirs @xmldir unless File.directory? @xmldir
      
      @rdfdir = File.join(@datadir, 'bibframe', @format)
      FileUtils.makedirs @rdfdir unless File.directory? @rdfdir
    end

    def convert_singles 
      @bibids.each do |id|
        xmlfilename = bibid_to_marcxml id  
        if xmlfilename && ! xmlfilename.empty?   
          marcxml_to_bibframe xmlfilename
        end
      end
    end
    
    def convert_batch
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
      
      rdffile = File.join(@rdfdir, File.basename(xmlfilename, FILE_EXTENSIONS['marcxml']) + FILE_EXTENSIONS[@format])
 
      # Saxon 9.6 removed support for defaults in favor of the XQuery 3.0 
      # syntax, so the usebnode value must be specified. 
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

    
    def sg_or_pl(string, count)
      count.to_s + ' ' + string + (count == 1 ? '' : 's')
    end

end