
require 'daemons'

Daemons::Controller.class_eval do
  def print_usage
    puts "Usage: #{@app_name} {start|stop|restart}"
  end
end
