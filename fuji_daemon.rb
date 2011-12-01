
$LOAD_PATH.push(File.dirname(__FILE__))

require 'rubygems'
require 'daemons'
require 'daemons_controller_class_eval'

options = {
  :app_name => 'fuji_ftp'
}

Daemons.run(File.join(File.dirname(__FILE__), './fuji_ftp.rb'), options)
