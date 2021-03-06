# Объект для управления удалённым устройством по протоколу HTTP.
# Удалённое устройство - это точно такой же микрокомпьютер с аналогичным web-сервером.
# Взаимодействие осуществляется при помощи GET-запроса.
# В атрибуте *address* должно быть прописано имя сервера или IP-адрес удалённого устройства
# (либо в виде 192.168.0.55 либо subdomain.subdomain.domain).
# Для аутентификации будет использован email и зашифрованный пароль первого администратора (с наименьшим id)
# т.е. на удалённом сервере должен быть пользователь с таким же email-ом и с таким же паролем.
# При первом вызове на удалённом сервере будет создан пользователь с именем remote.email_администратора с идентичным зашифрованным паролем.
# Если такой пользователь уже есть (а он должен быть в целях безопасности), его нужно удалить перед первым вызовом удалённого метода.

# Если пароль администратора в дальнейшем будет изменён, на удалённом сервере также нужно просто удалить этот логин и
# обратиться один раз к удалённому серверу, вызвав любой метод. Таким образом remote-логин будет пересоздан.
#
# Примеры использования:
# 1. Включить удалённое реле:
#   remote_device_name.remote_entity_name.on!
# где
#   "remote_device_name" - имя объекта Remote,
#   "remote_entity_name" - имя устройства на удалённой машине
#
# 2. Прочитать значение температуры на удалённом устройстве:
#   remote_temperature = remote_device_name.remote_entity_name.value
#
# 3. Установить положение и угол удалённой рафшторы:
#   remote_device_name.hall_facade_blind_1.set_position_and_tilt!(50, 45)


class Server < Device
  require 'net/http'
  require 'yaml'
  require 'socket'

  PROTOCOL_PREFIX = 'http://'

  # Вызывает метод *method_name* объекта *remote_entity_name* на удалённом сервере
  # Вместо прямого вызова этого метода лучше пользоваться следующим синтаксисом:  remote_server.remote_object.remote_method(parameter1,...)
  def execute_remote_method(remote_entity_name, method_name, *arguments)
    uri = address
    uri = PROTOCOL_PREFIX + uri unless address.start_with?(PROTOCOL_PREFIX)
    uri += '/' unless uri.end_with?('/')
    uri += 'remote/'
    uri = URI(uri)

    admin = User.where(isadmin: true).first

    uri.query = URI.encode_www_form(entity: remote_entity_name, method: method_name, params: arguments.to_yaml, email: admin.email, pwd: admin.encrypted_password)
    request = Net::HTTP::Get.new(uri)

#    request = Net::HTTP::Post.new(uri)
#    request.set_form_data(entity: remote_entity_name, method: method_name, params: params.to_yaml)

    response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 3) do |http|
      http.request(request)
    end

    case response
      when Net::HTTPSuccess
        YAML::load(response.body)
      else
        raise "#{ response.body }. Invalid response from remote server(#{ response.value }). Address: #{ uri.host }, entity: #{ remote_entity_name }, method: #{ method_name }, arguments: #{ arguments.to_s }"
    end
  end

  # Возвращает ip-адрес сервера
  def local_ip_address
    Socket.ip_address_list.detect{|intf| intf.ipv4_private?}.try(:ip_address)
  end

  # Проверяет, является ли инстанс локальным сервером, т.е. совпадает ли его поле address c ip - адресом текущего процесса
  def local?
    address.sub(PROTOCOL_PREFIX,'').chomp('/') == local_ip_address
  end

  protected

  class MethodProxy
    attr_accessor :owner, :remote_entity_name

    def initialize(owner, remote_entity_name)
      self.owner, self.remote_entity_name = owner, remote_entity_name
    end

    def method_missing(method_sym, *arguments, &block)
      owner.execute_remote_method(remote_entity_name, method_sym, *arguments)
    end

  end

  def method_missing(method_sym, *arguments, &block)
    if block || arguments.any?
      super
    else
      MethodProxy.new(self, method_sym)
    end
  end

end