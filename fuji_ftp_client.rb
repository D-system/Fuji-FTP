
# Handle each client
class FujiFtpClient
  def initialize(socket, yml)
    @cs = socket
    @yml = yml
    @connected = false
    @name = nil
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

  def ftp_530(c, args)
    @cs.write "530 Not logged in.\r\n"
    0
  end

  def ftp_500(c, args)
    puts "'#{c}' command unrecognized"
    @cs.write "500 '#{c}' command unrecognized\r\n"
    0
  end

  def ftp_503(c, args)
    @cs.write "503 Bad sequence of commands.\r\n"
    0
  end

  def ftp_exit(c, args)
    @cs.write "221 Thank you for using Fuji FTP\r\n"
    -1
  end

  def ftp_user(c, args)
    @connected = false
    @name = nil
    if not @yml['ftp']['users'].has_key?(args.strip!)
      @cs.close
      -1
    end
    @name = args
    @cs.write "331 User name okay, need password.\r\n"
    0
  end

  def ftp_pass(c, args)
    if @name.nil?
      return ftp_503(c, args)
    end
    if not @yml['ftp']['users'][@name] == args.strip!
      @cs.write "500 Illegal username\r\n"
      @name = nil
      return 0
    end
    @connected = true
    @cs.write "230 User #{args} logged in.\r\n"
    0
  end

  def ftp_type(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    ftp_502 c, args
    0
  end

  def ftp_list(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    ftp_502 c, args
    0
  end

  def ftp_pasv(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    ftp_502 c, args
    0
  end

  def ftp_pwd(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    ftp_502 c, args
    0
  end

  def ftp_stor(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    ftp_502 c, args
    0
  end

  def ftp_retr(c, args)
    if not @connected
      return ftp_530(c, args)
    end
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
        if func.call($1, $2) == -1
          break
        end
      rescue NameError => e
        puts e
        ftp_500 $1, $2
      end
    end
    puts "[#{Process.pid}] Killing connection from #{peeraddr[2]}:#{peeraddr[1]}"
    @cs.close
  end

end

