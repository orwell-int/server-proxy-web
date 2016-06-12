require 'rubygems'
require 'reloader/sse'
require_relative '../messages/controller.pb'
require_relative '../messages/server-game.pb'
require 'time'

class EventsController < ApplicationController
  include ActionController::Live

  def index
    puts "EventsController.index enter"
    response.headers['Content-Type'] = 'text/event-stream'
    sse = Reloader::SSE.new(response.stream)
    # do not know when this should finish yet
    finished = false
    new_message = true
    #logger = Logger.new(STDOUT)
    logger.datetime_format = "%Y-%m-%d %H:%M:%S:%L"
    begin
      begin
        if (new_message)
          before = Time.now.strftime('%Y%m%d%H%M%S%1N').to_i
          #puts "before = " + before.to_s
          new_message = false
        end
        zmq_message = Rails.application.zmq_receive_non_blocking()
        if (zmq_message != nil)
          new_message = true
          after = Time.now.strftime('%Y%m%d%H%M%S%1N').to_i
          #puts "after = " + after.to_s
          exploded = zmq_message.split(/ /, 3)
          tid = exploded[0]
          message_type = exploded[1]
          payload = exploded[2]
          if ("GameState" == message_type)
            if (tid != "all_clients")
              next
            end
            begin
              gamestate = Orwell::Messages::GameState.parse(payload)
            rescue ProtocolBuffers::DecodeError => e
              logger.error e.message + "\n " + e.backtrace.join("\n ")
              #$stderr.print "Decoding failed: " + $!
              raise
            end
            if gamestate.playing
              #print "game running "
              if gamestate.has_winner?()
                status = "won by team " + gamestate.winner
                print "winner = " + gamestate.winner + " "
              else
                status = "running"
                #print "no winner "
                if gamestate.has_seconds?()
                  status += " (#{gamestate.seconds} seconds left)"
                  #print "seconds left: #{gamestate.seconds} "
                  puts "left: #{gamestate.seconds} s"
                end
              end
            else
              status = "not started (yet)"
              #print "game NOT running "
            end
            sse.write({status: status})
          end
          delta = after - before
          t = Time.now
          puts "At " + t.strftime("%Y-%m-%d %H:%M:%S:%L").to_s + " - delta = " + delta.to_s
          #logger.debug { "delta = " + delta.to_s }
        else
          sleep 0.005
        end
      end until finished
    rescue IOError => e
      # Client Disconnected
      puts "caught exception #{e}!"
    ensure
      sse.close
    end
    render nothing: true
    puts "EventsController.index exit"
  end
end
