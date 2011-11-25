
# Handle each client
class VolcanoFtpClient
  def initialize(socket, yml)
    @cs = socket
    @yml = yml
  end

  def ftp_syst(c, args)
    @cs.write "215 UNIX Type: L8\r\n"
    0
  end

  def ftp_noop(c, args)
    @cs.write "200 Don't worry my lovely client, I'm here ;)"
    0
  end

  def ftp_502(c, args)
    puts "Command '#{c}' not implemented"
    @cs.write "502 Command '#{c}' not implemented\r\n"
    0
  end

  def ftp_500(c, args)
    puts "'#{c}' command unrecognized"
    @cs.write "500 '#{c}' command unrecognized\r\n"
    0
  end

  def ftp_exit(c, args)
    @cs.write "221 Thank you for using Fuji FTP\r\n"
    -1
  end

  def ftp_user(c, args)
    ftp_502 c, args
    0
  end

  def ftp_pass(c, args)
    ftp_502 c, args
    0
  end

  def ftp_type(c, args)
    ftp_502 c, args
    0
  end

  def ftp_list(c, args)
    ftp_502 c, args
    0
  end

  def ftp_pasv(c, args)
    ftp_502 c, args
    0
  end

  def run
    puts "[#{Process.pid}] Instanciating connection from #{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}"
    peeraddr = @cs.peeraddr.dup
    @cs.write "220-\r\n\r\n Welcome to Fuji FTP server !\r\n\r\n220 Connected\r\n"
    while not (line = @cs.gets).nil?
      puts "[#{Process.pid}] Client sent : --#{line}--"
      ####
      # Handle commands here
      ####
      begin
        func = method('ftp_' + line[/[\s]*([\w]*)[\s]+(.*)/, 1].downcase);
        func.call $1, $2
      rescue NameError => e
        puts e
        ftp_500 $1, $2
      end
    end
    puts "[#{Process.pid}] Killing connection from #{peeraddr[2]}:#{peeraddr[1]}"
    @cs.close
  end

end

