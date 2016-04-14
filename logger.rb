class Logger

  def initialize config
    
    @log_destinations = get_log_destination config
    @start_time = config[:start_time]
    @filename_start_time = @start_time.strftime '%Y-%m-%d-%H%M%S'
    
    create_log_dir 
    
    # Verbose logging is only to stdout, so true only if logging includes 
    # stdout
    @verbose = @log_destinations[:stdout] && config[:verbose] ? true : false
    if config[:verbose] && !@log_destinations[:stdout]
      log "Verbose logging turned off, since logging to stdout is turned off"
    end
  end

  def log_destinations
    @log_destinations
  end


  def log message
    
    if message.is_a? Array
      message = message.join("\n")
    end
    
    # Write the log to a file, if specified
    if @log_destinations[:file]
      File.open(@log_destinations[:file], 'a') do |f| 
        f.puts message 
      end
    end
  
    # Write the log to stdout, if specified
    if @log_destinations[:stdout]
      puts message
    end    
  end
  

  def log_verbose message
    if @verbose
      # Verbose messages go only to the console
      puts message
    end
  end

    
  def log_error message
    log message
    # Log an error to the console even if logging to stdout is turned off
    if ! @log_destinations[:stdout]
      puts message
    end
  end
  

  def formatted_start_time    
    @start_time.strftime '%Y-%m-%d-%H%M%S'
  end

  def formatted_datetime time
    time.strftime '%Y-%m-%d %T%z'
  end
  
  def verbose?
    return @verbose
  end
  
  def seconds_to_time(seconds)
    floor = seconds.floor
    h = floor / 3600
    m = floor / 60 % 60
    s = seconds.round % 60

    # [h, m, s].map { |t| t.to_s.rjust(2, '0')}.join(':')
    sprintf "%02d:%02d:%02d", h, m, s
  end
  
  def sg_or_pl(string, count)
    count.to_s + ' ' + string + (count == 1 ? '' : 's')
  end
  
private  
   
  def get_log_destination config
    
    log_destination = {:stdout => false, :dir => nil}
    
    # Yaml converts 'off' to false; don't call split() on false
    if config[:logging] 
      logging = config[:logging].split(%r{,\s*})
      
      if logging.include? 'file'
        log_destination[:dir] = config[:logdir]
      end 
      
      if logging.include? 'stdout'
        log_destination[:stdout] = true
      end 
    end
    
    log_destination    
  end


  def create_log_dir

    logdir = @log_destinations[:dir]
    if logdir       
        FileUtils.makedirs logdir
        @log_destinations[:file] = 
          File.join(logdir, formatted_start_time + '.log')
    end
  end



       
end