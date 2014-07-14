require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'ffi-rzmq'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

ENV.update YAML.load_file('config/application.yml')[Rails.env] rescue {}

def error_check(rc)
  if ZMQ::Util.resultcode_ok?(rc)
    false
  else
    STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
    caller(1).each { |callstack| STDERR.puts(callstack) }
    true
  end
end

module Orwell
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    def zmq_send(zmq_message)
      rc = @push_socket.send_string(zmq_message)
      if (not error_check(rc))
        print "push zmq_message = " + zmq_message.inspect + "'\n"
      end
    end

    def zmq_receive()
      zmq_message = ""
      rc = @subscribe_socket.recv_string(zmq_message)
      if (not error_check(rc))
        print "subscribe zmq_message = " + zmq_message.inspect + "'\n"
      end
      return zmq_message
    end

    def initialize!(*)
      super
      @context = ZMQ::Context.new
      @push_socket = @context.socket ZMQ::PUSH
      @push_socket.setsockopt(ZMQ::LINGER, 0)
      rc = @push_socket.connect(ENV['push_address'])
      error_check(rc)
      puts "Push socket created"
      @subscribe_socket = @context.socket ZMQ::SUB
      @subscribe_socket.setsockopt(ZMQ::LINGER, 0)
      @subscribe_socket.setsockopt(ZMQ::SUBSCRIBE, '')
      rc = @subscribe_socket.connect(ENV['subscribe_address'])
      error_check(rc)
      puts "Subscribe socket created"
    end

  end
end
