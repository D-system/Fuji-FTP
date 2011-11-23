
# Handle each client
class VolcanoFtpClient
  def initialize(socket)
    @cs = socket
  end

  def ftp_syst(args)
    @cs.write "215 UNIX Type: L8\r\n"
    0
  end

  def ftp_noop(args)
    @cs.write "200 Don't worry my lovely client, I'm here ;)"
    0
  end

  def ftp_502(*args)
    puts "Command not found"
    @cs.write "502 Command not implemented\r\n"
    0
  end

  def ftp_exit(args)
    @cs.write "221 Thank you for using Fuji FTP\r\n"
    -1
  end

  def run
    puts "[#{Process.pid}] Instanciating connection from #{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}"
    peeraddr = @cs.peeraddr.dup
    @cs.write "220-\r\n\r\n Welcome to Fuji FTP server !\r\n\r\n220 Connected\r\n"
    while not (line = @cs.gets).nil?
      puts "[#{Process.pid}] Client sent : --#{line.strip!}--"
      ####
      # Handle commands here
      ####
    end
    puts "[#{Process.pid}] Killing connection from #{peeraddr[2]}:#{peeraddr[1]}"
    @cs.close
  end

end

