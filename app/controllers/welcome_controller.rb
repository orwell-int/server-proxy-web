require 'rubygems'
require_relative '../messages/controller.pb'
require_relative '../messages/server-game.pb'

class WelcomeController < ApplicationController
  @@semaphore = Mutex.new
  @@last_data = {}

  #def initialize!(*)
    #super
  #end

  def index
    @@semaphore.synchronize {
      inner_index()
    }
  end

  def inner_index
    data = params[:data]
    clean_session = "CLEAN_SESSION" == data
    if ((not session.key?(:welcome)) or (clean_session))
      session[:routing_id] = ""
      session[:videofeed] = ""
      session[:status] = "Game not started"
      session[:welcome] = false
    end
    if (clean_session)
      puts "Session cleaned"
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
        message_type = exploded[1]
        payload = exploded[2]
        if ("Welcome" == message_type)
          if (tid != temp_id)
            next
          end
          welcome = Orwell::Messages::Welcome.parse(payload)
          robot = welcome.robot
          session[:routing_id] = welcome.id
          @@last_data[session[:routing_id]] = nil
          video_address = welcome.video_address
          video_port = welcome.video_port
          session[:videofeed] = "http://" + video_address + ":" + video_port.to_s
          puts "robot = " + robot
          puts "id = " + session[:routing_id]
          puts "video_address = " + video_address
          puts "video_port = " + video_port.to_s
          puts "videofeed = " + session[:videofeed]
          received = true
          session[:welcome] = true
        elsif ("Goodbye" == message_type)
          if (tid != temp_id)
            next
          end
          print "We are not welcome !\n"
          received = true
        elsif ("GameState" == message_type)
          if (tid != temp_id) and (tid != "all_clients")
            next
          end
          print "GameState"
          gamestate = Orwell::Messages::GameState.parse(payload)
          puts "GameState ..."
          puts gamestate
          if gamestate.playing
            print "game running "
            if gamestate.has_winner?()
              @status = "Game won by team " + gamestate.winner
              print "winner = " + gamestate.winner + " "
            else
              @status = "Game running"
              print "no winner "
              if gamestate.has_seconds?()
                @status += " (#{gamestate.seconds} seconds left)"
                print "seconds left: #{gamestate.seconds} "
              end
            end
          else
            @status = "Game not started (yet)"
            print "game NOT running "
          end
          session[:status] = @status
        end
      end
    end
    if (session[:welcome])
      print "BATMAN went ", @@last_data[session[:routing_id]], "\n"
      if (data == @@last_data[session[:routing_id]])
        @videofeed = session[:videofeed]
        @status = session[:status]
        return
      end
      print "BATMAN goes ", data, "\n"
      @@last_data[session[:routing_id]] = data
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
    @videofeed = session[:videofeed]
    @status = session[:status]
  end
end
