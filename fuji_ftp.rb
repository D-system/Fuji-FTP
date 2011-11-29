#!/usr/bin/env ruby
require "socket"
include Socket::Constants
load "fuji_ftp_client.rb"
require 'yaml'

# Fuji FTP class
class FujiFtp
  def initialize(yml_fn)
    # Prepare instance
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
    begin
      @socket = TCPServer.new(@yml['ftp']['port'])
    rescue SystemCallError => e
      puts e.message
      puts " -> Port #{port} already in use ?"
      Kernel.exit -1
    rescue => e
      puts e.message
      puts " -> Wrong parameter ?"
      Kernel.exit -1
    end
    @socket.listen(42)
    @threads = []
    @tsocket = nil
    puts "Server ready to listen for clients on port #{@yml['ftp']['port']}"
  end

  def run
    loop do
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

begin
  ftp = FujiFtp.new('fuji_conf.yml')
  ftp.run
rescue SystemExit
  puts "Exiting."
rescue Interrupt
  puts "Caught CTRL+C, exiting"
rescue RuntimeError => e
  puts e
end
