module EntityVisualization
  extend ActiveSupport::Concern
  
  included do
    register_attributes(:caption_class)

    attr_accessor(:redirect_target)
  end

  def human_value
    ("%g" % ("%.2f" % value) if value).to_s
  end

  def image
    icon_relative_location = "entities"
    file_exts = %w[png gif jpg jpeg]
    file_bases = [(image_name||name).to_s] + self.class.ancestors_and_self(Entity.superclass).map{|c| c.name.downcase} 
    file_values =  []
    file_values << '.'+human_value if value
    file_values << ''
    files = Dir.entries Rails.root.join('app','assets','images',icon_relative_location)
    files += Dir.entries Home::Engine.root.join('app','assets','images',icon_relative_location)
    
    for file_base in file_bases
      for file_value in file_values
        for file_ext in file_exts
          f = "#{ file_base+file_value }.#{ file_ext }"
          return File.join(icon_relative_location,f) if files.include? f 
        end
      end
    end
    nil
  rescue Exception
    nil
  end

  # Перенаправляет браузер на заданный объект либо страницу
  #
  # Параметры:
  # +target+ : Entity || String
  #
  # Пример вызова:
  #   at_click do
  #     redirect_to floor1
  #   end
  def redirect_to(target)
    self.redirect_target = target
  end

  # @!visibility private
  def img
    ActionController::Base.helpers.asset_path(image)
  end


  module ClassMethods
    # class methods
  end  
end