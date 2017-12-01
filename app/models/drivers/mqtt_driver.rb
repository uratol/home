require 'mqtt'


=begin
# Publish example
MQTT::Client.connect('test.mosquitto.org') do |c|
  c.publish('test', {method: :send, param1: 10.3})
end

# Subscribe example
MQTT::Client.connect('test.mosquitto.org') do |c|
  # If you pass a block to the get method, then it will loop
  c.get('test') do |topic,message|
    puts "#{topic}: #{message}"
    false
  end
end
=end


module MqttDriver
  DEFAULT_BROKER_ADDRESS = Rails.env.production? ? 'localhost' : 'test.mosquitto.org'

  mattr_accessor :brokers
  self.brokers = {}

  def self.watch(&block)
    startup

    @threads.each(&:kill) if (@threads ||= []).any?
    puts "MQTT sensors #{ sensors.pluck(:name).join(',') } will be watching"
    sensors.each do |sensor|
      @threads << Thread.new(block) do |trigger|
        sensor.broker.get(sensor.address) do |topic,message|
          trigger.call(topic, message.to_f)
        end
      end
    end
    @threads.each(&:join)
  end

  def self.startup
    devices.map{|s| s.broker_address.strip || DEFAULT_BROKER_ADDRESS }.uniq.each do |broker_addr|
      brokers[broker_addr] = MQTT::Client.connect(broker_addr)
    end
  end

  def self.devices
    Entity.where(driver: :mqtt).where.not(address: nil)
  end

  def self.sensors
    Sensor.where(driver: :mqtt).where.not(address: nil)
  end

  def broker_address
    DEFAULT_BROKER_ADDRESS
  end



  def set_driver_value(v)
    broker.publish(address, v)
  end

  private

  def broker
    self.brokers[broker_address]
  end

end