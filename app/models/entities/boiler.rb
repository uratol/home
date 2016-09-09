class Boiler < Actor
  register_attributes caption_class: 'center-bottom-inner' 

  def init
    super
    @shedule = 30.seconds
  end  
  
  def text
    if pwm_power
      "#{ (pwm_power * 100).round }%"
    else
      on? ? 'ON' : 'OFF'  
    end
  end
end