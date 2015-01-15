require 'fileutils'

class Converter

  # Set variables and create directories common to all bibids in the conversion
  # request
  def initialize config

    config.each {|k,v| instance_variable_set("@#{k}",v)}

    @log = {
      :message => [],
      :records => [],
      :no_records => [],
    }  

    @rdfext = get_rdf_ext 
      
    datetime = Time.now.strftime('%Y%m%d-%H%M%S')
    @logfile = File.join(@logdir, datetime + '.log')
    @datadir = File.join(@datadir, datetime)      
    
    @saxon = File.join('lib', 'saxon', 'saxon9he.jar')
    @xquery = File.join('lib', 'marc2bibframe', 'xbin', 'saxon.xqy') 
    # Non-rdfxml formats require an additional parameter to the LC converter
    @method = (@format == 'ntriples' || @format == 'json') ? "!method=text" : ''
    
    create_data_directories
  end

  def convert

    # Process the conversions
    @bibids.each do |id|
      xmlfile = bibid_to_marcxml id  
      if xmlfile     
        marcxml_to_bibframe id, xmlfile
      end
    end    
  end

  # Write the log to file
  def log
      
    totals_log = "#{sg_or_pl('bib id', @bibids.length)} processed."
    
    records_log = "#{sg_or_pl('record', @log[:records].length)} found and converted to bibframe"
    if @log[:records].length > 0
      records_log << ': ' + @log[:records].join(', ')
    end
    records_log << '.'
    
    no_records_log = "#{sg_or_pl('id', @log[:no_records].length)} without a bib record"
    if @log[:no_records].length > 0
      no_records_log << ': ' + @log[:no_records].join(', ')
    end
    no_records_log << '.'
    
    @log[:message] << [ totals_log, records_log, no_records_log ]
    
    if (! File.directory?(@logdir) )
      puts 'creating logdir ' + @logdir
      Dir.mkdir @logdir
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
    
    def get_rdf_ext
      # Set bibframe file extension based on serialization format
      return '.' +
        case @format
          when 'rdfxml', 'rdfxml-raw' then 'rdf'
          when 'json' then 'js'
          when 'ntriples' then 'nt'
          # when 'turtle' then 'ttl'
          else 'rdf' # shouldn't get here
        end
    end
    
    # Get marcxml for the bibid and write to a file
    def bibid_to_marcxml id
    
      # Retrieve the marcxml from the Voyager catalog. Include timestamp.
      marcxml_url = File.join(@catalog, id + '.marcxml')
      marcxml = `curl -s #{marcxml_url}`
      if (! marcxml.start_with?("<record"))
        @log[:no_records] << id
        return nil
      end
  
      @log[:records] << id
  
      # Wrap in <collection> tag. Doesn't make any difference in the bibframe of 
      # a single record, but is needed to process multiple records into a single 
      # file, so just add it generally.
      marcxml = marcxml.gsub(/<record xmlns='http:\/\/www.loc.gov\/MARC21\/slim'>/,
        "<?xml version='1.0' encoding='UTF-8'?><collection xmlns='http://www.loc.gov/MARC21/slim'>\n
        <record>") 
      marcxml << '</collection>'
  
      # Pretty print the unformatted marcxml for display purposes
      marcxml = `echo "#{marcxml}" | xmllint --format -`       
      # puts marcxml 
      
      # Write marcxml to file
      xmlfile = File.join(@xmldir, id + '.xml')
      File.open(xmlfile, 'w') { |file| file.write marcxml }
      
      return xmlfile
    end

    # Convert marcxml for the id to bibframe rdf and write to file
    def marcxml_to_bibframe id, xmlfile
      rdffile = File.join(@rdfdir, id + @rdfext)  
      @bibframe = `java -cp #{@saxon} net.sf.saxon.Query #{@method} #{@xquery} marcxmluri=#{xmlfile} baseuri=#{@baseuri} serialization=#{@format} > #{rdffile}`
    end
    
    def sg_or_pl(string, count)
      count.to_s + ' ' + string + (count == 1 ? '' : 's')
    end

end