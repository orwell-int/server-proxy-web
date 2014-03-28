require 'rubygems'
require_relative '../messages/controller.pb'
require 'ffi-rzmq'

def error_check(rc)
  if ZMQ::Util.resultcode_ok?(rc)
    false
  else
    STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
    caller(1).each { |callstack| STDERR.puts(callstack) }
    true
  end
end

class WelcomeController < ApplicationController
  @@socket = nil
  @@context = nil
  @@last_data = nil
  def initialize
    super

    @videofeed=ENV['videofeed']
    if nil == @@socket
      @@context = ZMQ::Context.new
      @@socket = @@context.socket ZMQ::PUSH
      @@socket.setsockopt(ZMQ::LINGER, 0)
      rc = @@socket.connect(ENV['push_address'])
      error_check(rc)
      puts "Socket created"
    end
  end
    
  def index
    data = params[:data]
    print "BATMAN went ", @@last_data, "\n"
    if (data == @@last_data)
      return
    end
    print "BATMAN goes ", data, "\n"
    @@last_data = data
    #left = 0.001
    #right = 0.001
    left = 0
    right = 0
    fire_weapon1 = false
    fire_weapon2 = false
    factor = 0.5
    if ("LEFT" == data)
      left = -1 * factor
      right = 1 * factor
    elsif ("FORWARD" == data)
      left = 1 * factor
      right = 1 * factor
    elsif ("RIGHT" == data)
      left = 1 * factor
      right = -1 * factor
    elsif ("BACKWARD" == data)
      left = -1 * factor
      right = -1 * factor
    elsif ("FIRE1" == data)
      fire_weapon1 = true
    elsif ("FIRE2" == data)
      fire_weapon2 = true
    end
    input = Orwell::Messages::Input.new(
      :move => Orwell::Messages::Input::Move.new(
	:left => left,
	:right => right),
      :fire => Orwell::Messages::Input::Fire.new(
	:weapon1 => fire_weapon1,
	:weapon2 => fire_weapon2))
    print "input = '", input.to_json, "'\n"
    bytes = input.to_s
    zmq_message = "BananaOne Input " + bytes
    #print "bytes = '" + bytes.inspect + "'\n"
    rc = @@socket.send_string(zmq_message)
    if (not error_check(rc))
      print "zmq_message = " + zmq_message.inspect + "'\n"
    end
  end
end
