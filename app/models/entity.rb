class Entity < ActiveRecord::Base
  
  extend EntityClassMethods 

  belongs_to :parent, class: Entity
  has_many :indications, dependent: :destroy
  has_many :jobs, class_name: :EntityJob, dependent: :destroy
  validates :name, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]+\Z/ }
  validates :caption, presence: true
  validates :type, presence: true
  validate :name_valid?
  # has_closure_tree
  acts_as_nested_set dependent: :restrict, counter_cache: :children_count, depth_column: :depth
  has_many :children, class: Entity, foreign_key: :parent_id, dependent: :restrict_with_error
  attr_accessor :state
  attr_accessor :image_name, :width, :height
  attr_reader :events
  
  after_initialize :init
  
  include ::EntityVisualization
  include ::EntityBehavior
  
  register_events :at_click
  
  def value_at dt
    (indication_at(dt) || self).value
  end

  def indication_at dt
    Indication.indication_at self, dt
  end
  
  def types
    self.class.types
  end
  
  def behavior_methods
    self.class.instance_methods.grep(/^at_/)
  end
  
  def twins
    Entity.where(driver: driver, address: address) unless address.to_s.blank? || driver.to_s.blank?
  end
  
  
  def twin_id
    tw = twins
    tw.minimum(:id) if tw
  end
  
  def original?
    tw_id = twin_id
    tw_id.nil? || tw_id==id
  end
  
  def to_s
    name ? "#{ name } (#{ caption })" : super
  end
  
  def inspect
    "#<#{self.class.name}: #{name}>"
  end
  
  def do_event event_name
    events.call event_name 
  end

  def write_value v
    transaction do
      store_value v
      tw = twins 
      twins.where.not(id: id).update_all value: v if tw
    end  
    return v
  end

  protected

  def store_value v, dt = Time.now
    old_value = self.value

    set_driver_value v if is_a?(Actor) && !driver.blank?

    if (dbl_change_assigned = events.assigned?(:at_dbl_change) ) 
      last_indication = indications.limit(1).order('created_at DESC').first
      last_indication_time = if last_indication then last_indication.created_at else Time.now - 1.hour end         
      dbl_change_assigned = ((Time.now - last_indication_time) < 1.second)
    end

    self.value = v
    Entity.where(id: id).update_all(value: v)
#    update_attribute(:value, v) 
    
    if old_value != v
      do_event(if on? then :at_on else :at_off end)
      do_event :at_change
      do_event :at_dbl_change if dbl_change_assigned
    end  
    indications.create! value: v, dt: dt

  end
  
  def self.method_missing method_sym, *arguments, &block
    Entity[method_sym] || super
  end

  def method_missing method_sym, *arguments, &block
    Entity[method_sym] || super
  end
  
  private

  def init
    @events = EntityEvents.new
    self.state = []
    return if name.to_s.blank?
    extend "#{ driver }_driver".camelcase.constantize unless driver.blank?
  end
  

  def name_valid?
    errors.add :name, "\"#{name}\" is reserved" if Entity.instance_methods.include? name.to_sym
  end
  
  self.require_entity_classes
end

 

