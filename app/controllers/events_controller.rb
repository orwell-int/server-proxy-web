require 'rubygems'
require 'reloader/sse'
require_relative '../messages/controller.pb'
require_relative '../messages/server-game.pb'

class EventsController < ApplicationController
  include ActionController::Live

  def index
    puts "EventsController.index enter"
    response.headers['Content-Type'] = 'text/event-stream'
    sse = Reloader::SSE.new(response.stream)
    # do not know when this should finish yet
    finished = false
    begin
      begin
        zmq_message = Rails.application.zmq_receive()
        exploded = zmq_message.split(/ /, 3)
        tid = exploded[0]
        message_type = exploded[1]
        payload = exploded[2]
        if ("GameState" == message_type)
          if (tid != "all_clients")
            next
          end
          gamestate = Orwell::Messages::GameState.parse(payload)
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
              end
            end
          else
            status = "not started (yet)"
            #print "game NOT running "
          end
          sse.write({status: status})
        end
      end until finished
    rescue IOError
      # Client Disconnected
    ensure
      sse.close
    end
    render nothing: true
    puts "EventsController.index exit"
  end
end
