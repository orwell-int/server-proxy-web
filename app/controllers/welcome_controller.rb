require 'rubygems'
require_relative '../messages/controller.pb'
require_relative '../messages/server-game.pb'

class WelcomeController < ApplicationController
  def index
    if (not session.key?(:welcome))
      session[:routing_id] = ""
      session[:videofeed] = ""
      session[:welcome] = false
      session[:last_data] = nil
    end
    if (not session[:welcome])
      hello = Orwell::Messages::Hello.new(:name => 'Batman')
      print "hello = '", hello.to_json, "'\n"
      bytes = hello.to_s
      temp_id = "TemporaryID"
      zmq_message = temp_id + " Hello " + bytes
      #print "bytes = '" + bytes.inspect + "'\n"
      print Rails.application
      # this will block if no server game is ready to handle this
      Rails.application.zmq_send(zmq_message)
      received = false
      while (not received)
        zmq_message = Rails.application.zmq_receive()
        exploded = zmq_message.split(/ /, 3)
        tid = exploded[0]
        if (tid != temp_id)
          next
        end
        message_type = exploded[1]
        payload = exploded[2]
        if ("Welcome" == message_type)
          welcome = Orwell::Messages::Welcome.parse(payload)
          robot = welcome.robot
          session[:routing_id] = welcome.id
          video_address = welcome.video_address
          video_port = welcome.video_port
          session[:videofeed] = "http://" + video_address + ":" + video_port.to_s
          print "robot = " + robot + "\n"
          print "id = " + session[:routing_id]
          print "video_address = " + video_address + "\n"
          print "video_port = " + video_port.to_s + "\n"
          received = true
          session[:welcome] = true
        elsif ("Goodbye" == message_type)
          print "We are not welcome !\n"
          received = true
        elsif ("GameState" == message_type)
          print "GameState"
          gamestate = Orwell::Messages::GameState.parse(payload)
          puts gamestate
        end
      end
    end
    if (session[:welcome])
      data = params[:data]
      print "BATMAN went ", session[:last_data], "\n"
      if (data == session[:last_data])
        return
      end
      print "BATMAN goes ", data, "\n"
      session[:last_data] = data
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
      zmq_message = session[:routing_id] + " Input " + bytes
      #print "bytes = '" + bytes.inspect + "'\n"
      Rails.application.zmq_send(zmq_message)
    end
  end
end
