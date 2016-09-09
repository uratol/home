require "dht-sensor-ffi"

module DhtDriver
  def get_driver_value
    a = address.split(':')
    model = a.first.to_i
    pin_no = a.second.to_i
    r = DhtSensor.read(pin_no, model)
    
    bounds = lambda{|val, min, max| val if val.between?(min,max)}
    case self when Temperature then bounds.call(r.temperature,min || -50,max || 100) when Humidity then bounds.call(r.humidity, min || 1, max || 100) end
  end
  
  def self.models
    [11,22]
  end
  
  def self.description_data
    "DHT-XX type humidity/temperature sensor
    Address format: XX:P 
    where XX - kind of sensor, #{ models.join(" or ") }
    P - GPIO BCM pin number"
  end
  
  def self.scan
    
# too slow: DhtSensor.read lock all threads    
=begin    
    threads = []
    GpioDriver.bcm_pins.each do |pin|
      threads << Thread.new(pin) do |pin_no|
        print "scanning pin #{ pin_no }\n"
        begin
          byebug
          DhtSensor.read(pin_no, models.first)
        rescue
        else
          Thread.current[:pin_no] = pin_no
        end       
      end
    end
    pins = []
    threads.each do |t|
      print "join thread #{ t }\n"
      t.join(10.seconds)
      pin_no = t[:pin_no]
      print "joined pin #{ pin_no }\n"
      pins << pin_no if pin_no
    end  
    pins
=end    
    
    
    result = []
    models.map do |model|
      result += GpioDriver.bcm_pins.map{|p| "#{ model }:#{ p }"}
    end  
    result
  end
  
  
end