class EntityJobHandler
  
  attr_accessor :entity_id, :args, :options

  def initialize obj, options = {}
    return if performing?
    @entity, @options = obj, options
    if @entity && options[:source_row]
      raise "Block not found in behavior body script. Use method call instead" unless @entity.state.include? :behavior_script_eval
      shedule! 
    end
  end
  
  def enqueue job
#    puts "!enqueue! job=#{ job }, options=#{options}, next_run_time=#{ next_run_time }"
    job.entity_id = entity_id     
    job.queue = queue_name
  end
  
  def before job
    @entity = safe_find_entity job.entity_id
  end
  
  def perform

#puts "perform entity=#{@entity}, row=#{ options[:source_row] }, run_interval=#{ options[:run_interval] },  time=#{Time.now.sec}"    

    return unless @entity

    
    if options[:source_row]
      @entity.events.call options[:method], options
    else
      @entity.send options[:method], *args
    end
  end
  
  def success(job)
    shedule! job unless run_once? 
  end
      
  
  def method_missing(method, *args)
    return if performing?
    raise NoMethodError, "Undefined method '#{method}' for #{@entity.inspect}" unless @entity.respond_to? method
    self.args = args
    self.options[:method] = method
    shedule!
  end

  def max_run_time
    300 # seconds
  end
  
  def max_attempts
    3
  end  
  
  private
  
  ################ shedule!
  def shedule! current_job = nil
    return unless run_time = next_run_time

#puts "!shedule! current_job=#{ current_job }, options=#{options}, next_run_time=#{ next_run_time }, entity=#{ @entity}"      
      
#    query = @entity.jobs.where(queue: queue_name)
#    query = query.where.not(current_job.id) if current_job
      
    self.entity_id = @entity.id
    tmp_obj = remove_instance_variable :@entity # for avoiding serialization
    begin
      EntityJob.enqueue(self, run_at: run_time) 
    ensure  
      @entity = tmp_obj #return
    end
    return true
  end
  

  def run_once?
    !(options[:run_interval] || ([*options[:at]].length>1))
  end  

  def queue_name
    (options[:source_row] || options[:method]).to_s    
  end
  
  def next_run_time

    return if run_once?
    
    interval = @options[:run_interval]

    times = @options[:at] || Time.now
    times = [times] unless times.is_a? Array
    times = times.map{|time| parse_time(time, @options[:timezone])}
    times = times.map{|time| time.in_time_zone @options[:timezone]} if @options[:timezone]
  
  
    until (next_time = next_future_time(times))  || !interval
      times.map!{ |time| time + interval }
    end
  
    # Update @options to avoid growing number of calculations each time
    @options[:at] = times
  
    next_time  
  end

  def next_future_time(times)
    times.select{|time| time > Time.now}.min
  end    

  def parse_time(time, timezone)
    case time
    when String
      time_with_zone = get_timezone(timezone).parse(time)
      parts = Date._parse(time, false)
      wday = parts.fetch(:wday, time_with_zone.wday)
      time_with_zone + (wday - time_with_zone.wday).days
    else
      time
    end
  end

  def get_timezone(zone)
    if zone
      ActiveSupport::TimeZone.new(zone)
    else
      Time.zone
    end
  end
  
  @@performing_count=0

  #prevent enqueue jobs within entity initializer
  def safe_find_entity id
    @@performing_count+=1  
    begin
      result = Entity[id]
    ensure
      @@performing_count-=1
    end
    result
  end
  
  def self.performing?
    @@performing_count > 0
  end

  def performing?
    self.class.performing?
  end
  
end