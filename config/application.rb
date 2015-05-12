require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'ffi-rzmq'
require 'socket'

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
      push_address = ENV['push_address']
      subscribe_address = ENV['subscribe_address']
      if true
        # find the server through UDP broadcast
        udp_socket = UDPSocket.new
        udp_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
        ip = IPSocket.getaddress(Socket.gethostname)
        puts "ip = #{ip}"
        num_bytes_sent = udp_socket.send(ip, 0, '<broadcast>', ENV["broadcast_port"])
        puts "number of bytes sent: #{num_bytes_sent}"
        received = nil
        begin
          received = udp_socket.recvfrom_nonblock(512)
        rescue IO::EAGAINWaitReadable
          puts "No broadcast server available"
        end
        if (nil != received)
          puts "received info: #{received[1].inspect}"
          sender = received[1][3]
          data = received[0]
          puts "received data: #{data.inspect}"
          # data:
          # 0xA0
          # size on 8 bytes
          # Address of puller
          # 0xA1
          # size on 8 bytes
          # Address of publisher
          # 0x00
          fail "Missing 0xA0" if 0xA0 != data[0].ord
          puller_size = data[1].ord
          end_puller = 2 + puller_size
          puller_address = data[2,puller_size]
          fail "Missing 0xA1" if 0xA1 != data[end_puller].ord
          publisher_size = data[end_puller + 1].ord
          end_publisher = end_puller + 2 + publisher_size
          publisher_address = data[end_puller + 2, publisher_size]
          fail "Missing 0x00" if 0x00 != data[end_publisher].ord
          puts "puller_address = #{puller_address.inspect}"
          puts "publisher_address = #{publisher_address.inspect}"
          push_address = puller_address.sub('*', sender)
          subscribe_address = publisher_address.sub('*', sender)
        end
        udp_socket.close
      end
      @context = ZMQ::Context.new
      @push_socket = @context.socket ZMQ::PUSH
      @push_socket.setsockopt(ZMQ::LINGER, 0)
      rc = @push_socket.connect(push_address)
      error_check(rc)
      puts "Push socket created"
      @subscribe_socket = @context.socket ZMQ::SUB
      @subscribe_socket.setsockopt(ZMQ::LINGER, 0)
      @subscribe_socket.setsockopt(ZMQ::SUBSCRIBE, '')
      rc = @subscribe_socket.connect(subscribe_address)
      error_check(rc)
      puts "Subscribe socket created"
    end

  end
end
