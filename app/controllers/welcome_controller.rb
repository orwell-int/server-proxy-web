class WelcomeController < ApplicationController
  def index
    print "BATMAN goes ", params[:data]
  end
end
