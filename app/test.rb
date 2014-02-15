require 'rubygems'
require_relative 'messages/controller.pb'
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

def main
  data = "LEFT"
  print "BATMAN goes ", data, "\n"
  left = 0
  right = 0
  fire_weapon1 = false
  fire_weapon2 = false
  if ("LEFT" == data)
    left = -1
    right = 1
  elsif ("FORWARD" == data)
    left = 1
    right = 1
  elsif ("RIGHT" == data)
    left = 1
    right = -1
  elsif ("BACKWARD" == data)
    left = -1
    right = -1
  end
  #input = Input.new(
    #:move => Input::Move.new(
      #:left => left,
      #:right => right),
    #:fire => Input::Fire.new(
      #:weapon1 => fire_weapon1,
      #:weapon2 => fire_weapon2))
  input = Orwell::Messages::Input.new(
    :move => Orwell::Messages::Input::Move.new(
      :left => left,
      :right => right),
    :fire => Orwell::Messages::Input::Fire.new(
      :weapon1 => fire_weapon1,
      :weapon2 => fire_weapon2))
  #print "input = '", input.to_json, "'\n"
  ctx = ZMQ::Context.new
  socket = ctx.socket ZMQ::PUSH
  socket.setsockopt(ZMQ::LINGER, 1)
  rc = socket.connect("tcp://192.168.1.40:9000")
  error_check(rc)
  bytes = input.to_s
  print "bytes = " + bytes.inspect + "\n"
  zmq_message = "TANK_0 Input " + bytes
  socket.send_string(zmq_message)
  print "zmq_message = '" + zmq_message + "'\n"
end

if __FILE__ == $PROGRAM_NAME
  main
end
