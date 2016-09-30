class Humidity < Sensor

  register_attributes caption_class: 'center-bottom-inner' 

  def init
    super
    self.binary = false
    self.schedule = 1.minute
  end  

  def text
    "#{ value.try :round  } %"
  end

  private
  
  def on?
  end

  def off?
  end
    
end