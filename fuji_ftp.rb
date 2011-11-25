#!/usr/bin/env ruby
require "socket"
include Socket::Constants
load "fuji_ftp_client.rb"
require 'yaml'

# Volcano FTP contants
BINARY_MODE = 0
ASCII_MODE = 1
MIN_PORT = 1025
MAX_PORT = 65534

# Volcano FTP class
class VolcanoFtp
  def initialize(port, yml_fn)
    # Prepare instance
    @socket = TCPServer.new("", port)
    @socket.listen(42)

    @threads = []
    @transfert_type = BINARY_MODE
    @tsocket = nil
    begin
      @yml = YAML.load(File.open(yml_fn, 'r'))
    rescue ArgumentError => e
      puts "Could not parse configuration file: #{e.message}"
      puts "Exiting"
      Kernel.exit -1
      rescue SystemCallError => e
      puts e
      puts "Exiting"
      Kernel.exit -1
    end
    puts "Server ready to listen for clients on port #{port}"
  end

  def run
    while (42)
      selectResult = IO.select([@socket], nil, nil, 0.1)
      if selectResult == nil or selectResult[0].include?(@socket) == false
        @threads.each do |t|
          if t.stop?
            ####
            # Do stuff with newly terminated processes here
            ####
            @threads.delete(t)
          end
        end
      else
        cs,  = @socket.accept
        p cs.inspect + " dans le else"
        Thread.new(cs, @yml) do |cs, yml|
          @threads << Thread.current
          FujiFtpClient.new(cs, yml).run
          Thread.current.terminate
        end
      end
    end
  end

protected

  # Protected methods go here

end

# Main

if ARGV[0]
  begin
    ftp = VolcanoFtp.new(ARGV[0], 'fuji_conf.yml')
    ftp.run
  rescue SystemExit
  rescue Interrupt
    puts "Caught CTRL+C, exiting"
  rescue RuntimeError => e
    puts e
  end
end
