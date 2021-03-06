require 'pathname'

module EntityVisualization
  extend ActiveSupport::Concern
  ICON_RELATIVE_LOCATION = "entities"


  included do
    register_attributes(:caption_class)

    attr_accessor(:javascript)
    attr_accessor(:input_items)
  end

  def human_value
    ("%g" % ("%.2f" % value) if value).to_s
  end

  def image_value
    human_value
  end

  def image_files(for_export)
    return @files if @files

    @files = self.class.image_files(for_export, self)

=begin
    file_bases = [(image_name||name).to_s] + self.class.ancestors_and_self(Entity).map{|c| c.name.downcase}
    file_values =  []
    if for_export
      file_values << '.*'
    else
      file_values << '.' + image_value if value
    end
    file_values << ','

    search_mask = "{#{ file_bases.join(',') }}{#{ file_values.join }}.{png,gif,jpeg,jpg,webp,svg}"
    @files = Dir.glob(Rails.root.join('app','assets','images',ICON_RELATIVE_LOCATION, search_mask))
    @files += Dir.glob(Home::Engine.root.join('app','assets','images',ICON_RELATIVE_LOCATION, search_mask)) unless for_export

    for_export ? @files : @files.map{|f| File.join(ICON_RELATIVE_LOCATION, File.basename(f)) }
  end
=end
    end

  def image
    image_files(false).first
  end

  def images_for_export
    self_and_descendants
        .inject([]){|acc, entity| acc + entity.image_files(true) }
        .uniq
        .map{|file_name| {File.basename(file_name) => Base64.encode64(File.open(file_name, "rb").read) }}
  end

=begin
  def image
    file_exts = %w[png gif jpg jpeg]
    file_bases = [(image_name||name).to_s] + self.class.ancestors_and_self(Entity.superclass).map{|c| c.name.downcase}
    file_values =  []
    file_values << '.'+human_value if value
    file_values << ''

    files = image_files(true)
    file_bases.each {|file_base|
      file_values.each {|file_value|
        file_exts.each {|file_ext|
          f = "#{ file_base+file_value }.#{ file_ext }"
          return File.join(ICON_RELATIVE_LOCATION, f) if files.include? f
        }
      }
    }
    nil
  rescue Exception
    nil
  end
=end

  # returns full path to current image
  def img
    if (image_path = image)
      ActionController::Base.helpers.asset_path(image_path)
    end
  end


  # Redirects browser to object or url
  # @param target [Entity, String]
  # @example Redirect to object
  #   at_click do
  #     redirect_to floor1
  #   end
  # @example Redirect to url
  #   at_click do
  #     redirect_to 'http://google.com'
  #   end
  def redirect_to(target)
    execute_javascript("window.location = '#{ target.is_a?(Entity) ? "/show/#{ target.name }" : target }'")
  end

  # Provide access to browser request parameters, including {#input} users data
  # @return [Hash]
  def params
    controller.try(:params)
  end

  # Provide access to current Ruby On Rails controller
  # @return [ActionController::Base]
  def controller
    Entity.controller
  end

  # Allows you to request additional information from the user
  # by displaying a dialog box
  # @param [Array<Hash>] input_items contains array of [Hash] represented visual controls in dialog. Each [Hash] contains the keys:
  # @option input_items [String] :caption Caption of control, required.
  # @option input_items [:text, :number, :range, :checkbox, :select, :time, :date, :color] :type Type of control, default :text
  # @option input_items [String, Number] :default Default value of control
  # Depending on :type, other html properties can also be specified
  #
  # @return [true, false] Returns true at second method call, wherein #input[] contains user input data
  # @example
  #   at_click do
  #     if input(
  #         {caption: num = "number (%value)" , type: :range, default: data.num, min: 1, max: 15},
  #         {caption: "color", type: :color, default: data.color},
  #         {caption: "email", type: :email, default: data.text, size: 25, style: "background-color: #{ data.color }"},
  #         {caption: "select list", type: :select, select:  ['one','two','three'], default: 'two'},
  #         {caption: "check me", type: :checkbox, default: data.checked},
  #         {caption: how_long = "How Long?", type: :duration, default: '23:59', only: [:hours,:minutes]}
  #     )
  #       # store input data
  #       data.num = input[num]
  #       data.text = input["email"]
  #       data.color = input[color]
  #       data.checked = input["check me"]
  #       data.how_long = = input["how_long"]
  #     end
  #   end
  def input(*input_items)
    return @input_proxy ||= InputProxy.new(params) if input_items.empty?

    input_items.flatten!
    is_first_call = !(params[:input])
    @input_items = input_items if is_first_call
    !is_first_call
  end

  # Display the message in browser
  # @param text - text message
  def message(text)
    execute_javascript("message(\"#{ text.to_s.gsub('"', '\"') }\");");
  end

  # Allows you to run any javascript in browser
  def execute_javascript(script)
    @javascript = (@javascript || '') + script + (script.last != ';' ? ';' : '') # will be process in MainController
    self
  end

  def brightness
    nil
  end

  def text
    nil
  end

  def refresh_script
    nil
  end

  class InputProxy
    def initialize(params)
      @input_params = ActiveSupport::HashWithIndifferentAccess.new
      params[:input].each do |key, value_and_type|
        origin_value = value_and_type[:value]
        @input_params[key] = case value_and_type[:type]
                               when 'number', 'range'
                                 origin_value.to_f
                               when 'checkbox'
                                 ['on','true','1'].include?(origin_value)
                               when 'time','date','datetime'
                                 origin_value.try :in_time_zone
                               when 'duration'
                                 origin_value[:days].to_f.days +
                                     origin_value[:hours].to_f.hours +
                                     origin_value[:minutes].to_f.minutes +
                                     origin_value[:seconds].to_f.seconds
                               when 'schedule'
                                 TimedSchedule::Schedule.from_hash(origin_value.to_h)
                               else
                                 origin_value
                               end
      end
    end

    def [](input_name)
      @input_params[input_name]
    end

    def to_h
      @input_params
    end

  end

  module ClassMethods
    def menu_entities(root = nil)
      where('parent_id is null and (hidden=? or id=?)', false, root).order(:location_x)
    end

    def image_files(for_export, entity = nil)
      file_bases = []
      file_bases = [(entity.image_name||entity.name).to_s] if entity
      file_bases += ancestors_and_self(Entity).map{|c| c.name.downcase}
      file_values =  []
      if for_export || entity.nil?
        file_values << '.*'
      else
        file_values << '.' + entity.image_value if entity.value
      end
      file_values << ','

      search_mask = "{#{ file_bases.join(',') }}{#{ file_values.join }}.{png,gif,jpeg,jpg,webp,svg}"
      files = Dir.glob(Rails.root.join('app','assets','images',ICON_RELATIVE_LOCATION, search_mask))
      files += Dir.glob(Home::Engine.root.join('app','assets','images',ICON_RELATIVE_LOCATION, search_mask)) unless for_export

      for_export ? files : files.map{|f| File.join(ICON_RELATIVE_LOCATION, File.basename(f)) }
    end

    def image
      image_files(false, nil).first
    end

    def img
      if (image_path = image)
        ActionController::Base.helpers.asset_path(image_path)
      end
    end

  end

end