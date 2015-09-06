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

  class UdpBroadcaster
    attr_accessor :push_address
    attr_accessor :subscribe_address

    def initialize(port, retries, timeout_for_one_message)
      @port = port
      @udp_socket = UDPSocket.new
      @udp_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      @ip_list = Socket.ip_address_list.map{ |i| i.ip_address }.compact
      puts "retries ", retries
      puts "@ip_list.length ", @ip_list.length
      @retries = retries * @ip_list.length
      @ip_index = 0
      puts "ip_list = #{@ip_list}"
      @received = nil
      @push_address = nil
      @subscribe_address = nil
      @decding_successful = false
      @timeout = timeout_for_one_message
    end

    def has_decoded_message()
      return @decding_successful
    end

    def broadcast()
      send_all_broadcast_messages()
      try_to_decode_received_message()
      if not @decding_successful
        puts "No broadcast attempt received a valid reply."
      end
    end

    def send_all_broadcast_messages()
      tries = 0
      while tries < @retries and @received == nil
        ip = get_next_ip()
        send_one_broadcast_message(ip)
        try_to_receive_broadcast_response()
        tries += 1
      end
    end

    def get_next_ip()
      ip = @ip_list[@ip_index]
      @ip_index = (@ip_index + 1) % @ip_list.length
      return ip
    end


    def send_one_broadcast_message(ip)
      num_bytes_sent = @udp_socket.send(ip, 0, '<broadcast>', @port)
      puts "number of bytes sent: #{num_bytes_sent}"
    end
        
    def try_to_receive_broadcast_response()
      ready = IO.select([@udp_socket], nil, nil, @timeout)
      if ready
        @received = @udp_socket.recvfrom(512)
      else
        puts "No server found using broadcast"
      end
    end

    def try_to_decode_received_message()
      if @received != nil
        begin
          decode_received_message()
        rescue Exception => e
          puts e.message
        end
      end
    end

    def decode_received_message()
      puts "received info: #{@received[1].inspect}"
      sender = @received[1][3]
      data = @received[0]
      puts "received data: #{data.inspect}"
      # data (split on different lines for clarity):
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
      @push_address = puller_address.sub('*', sender)
      @subscribe_address = publisher_address.sub('*', sender)
      @decding_successful = true
    end

    private :send_all_broadcast_messages
    private :send_one_broadcast_message
    private :try_to_receive_broadcast_response
    private :try_to_decode_received_message
    private :decode_received_message

  end

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
        #print "subscribe zmq_message = " + zmq_message.inspect + "'\n"
      end
      return zmq_message
    end

    def initialize!(*)
      super
      push_address = ENV['push_address']
      subscribe_address = ENV['subscribe_address']
      if true
        broadcaster = UdpBroadcaster.new(
          ENV["udp_broadcast_port"].to_i,
          ENV["udp_broadcast_retries"].to_i,
          ENV["udp_broadcast_timeout"].to_i
        )
        broadcaster.broadcast()
        if broadcaster.has_decoded_message()
          push_address = broadcaster.push_address
          subscribe_address = broadcaster.subscribe_address
        end
      else
        # find the server through UDP broadcast
        udp_socket = UDPSocket.new
        udp_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
        ip = IPSocket.getaddress(Socket.gethostname)
        puts "ip = #{ip}"
        num_bytes_sent = udp_socket.send(ip, 0, '<broadcast>', ENV["udp_broadcast_port"])
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
          puts "push_address = #{push_address.inspect}"
          puts "subscribe_address = #{subscribe_address.inspect}"
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
