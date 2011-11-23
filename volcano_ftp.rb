#!/usr/bin/env ruby
require "socket"
include Socket::Constants
load "volcano_ftp_client.rb"

# Volcano FTP contants
BINARY_MODE = 0
ASCII_MODE = 1
MIN_PORT = 1025
MAX_PORT = 65534

# Volcano FTP class
class VolcanoFtp
  def initialize(port)
    # Prepare instance
    @socket = TCPServer.new("", port)
    @socket.listen(42)

    @pids = []
    @transfert_type = BINARY_MODE
    @tsocket = nil
    puts "Server ready to listen for clients on port #{port}"
  end

  def run
    while (42)
      selectResult = IO.select([@socket], nil, nil, 0.1)
      if selectResult == nil or selectResult[0].include?(@socket) == false
        @pids.each do |pid|
          if not Process.waitpid(pid, Process::WNOHANG).nil?
            ####
            # Do stuff with newly terminated processes here
            ####
            @pids.delete(pid)
          end
        end
        # p @pids
      else
        @cs,  = @socket.accept
        @pids << Kernel.fork do
          ftp = VolcanoFtpClient.new(@cs)
          ftp.run
        end
        Kernel.exit!
      end
    end
  end

protected

  # Protected methods go here

end

# Main

if ARGV[0]
  begin
    ftp = VolcanoFtp.new(ARGV[0])
    ftp.run
  rescue SystemExit, Interrupt
    puts "Caught CTRL+C, exiting"
  rescue RuntimeError => e
    puts e
  end
end
