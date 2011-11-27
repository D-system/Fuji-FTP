
require "socket"
include Socket::Constants
load "hash_class_eval.rb"

# Handle each client
class FujiFtpClient
  def initialize(socket, yml)
    @cs = {:cmd => socket, :data_accept => nil, :data => nil}
    @yml = yml
    @connected = false
    @name = nil
    @wd = '/'
    @passive = nil
    @data_port = nil
    @data_socket = nil
  end

  def get_data_socket
    if @passive.nil?
      ftp_425
      return -1
    end
    if @passive
      puts "get_data_socket passive connection !"
      ####
      # wait client on :data_accept if :data not set
      ####
      if not @cs[:data].nil?
        return @cs[:data]
      end
      if do_data_accept == 0
        return @cs[:data]
      else
        return -1
      end
    else
      puts "get_data_socket Active connection !"
      ####
      # connect to client
      ####
      return -1
    end
    -1
  end

  def do_data_accept
    puts "do_data_accept"
    begin
      @cs[:data] = @cs[:data_accept].accept
      @cs[:data].close_read
    rescue SystemCallError
      puts "Can't accept data connection"
      return -1
    rescue
      puts e.message
      puts "Something goes very bad to get data coonection"
      return -1
    end
    0
  end

  def ftp_502(c, args = nil)
    puts "Command '#{c}' not implemented"
    @cs[:cmd].write "502 Command '#{c}' not implemented\r\n"
    0
  end

  def ftp_530(c = nil, args = nil)
    @cs[:cmd].write "530 Not logged in.\r\n"
    0
  end

  def ftp_500(c, args = nil)
    puts "'#{c}' command unrecognized"
    @cs[:cmd].write "500 '#{c}' command unrecognized\r\n"
    0
  end

  def ftp_503(c = nil, args = nil)
    @cs[:cmd].write "503 Bad sequence of commands.\r\n"
    0
  end

  def ftp_425(c = nil, args = nil)
    @cs[:cmd].write "425 Can't open data connection.\r\n"
    0
  end    

  def ftp_syst(c = nil, args = nil)
    @cs[:cmd].write "215 UNIX Type: L8\r\n"
    0
  end

  def ftp_noop(c = nil, args = nil)
    @cs[:cmd].write "200 Don't worry my lovely client, I'm here ;)"
    0
  end

  def ftp_exit(c = nil, args = nil)
    @cs[:cmd].write "221 Thank you for using Fuji FTP\r\n"
    -1
  end

  def ftp_user(c, args)
    @connected = false
    @name = nil
    if not @yml['ftp']['users'].has_key?(args.strip!)
      @cs[:cmd].close
      -1
    end
    @name = args
    @cs[:cmd].write "331 User name okay, need password.\r\n"
    0
  end

  def ftp_pass(c, args)
    if @name.nil?
      return ftp_503(c, args)
    end
    if not @yml['ftp']['users'][@name] == args.strip!
      @cs[:cmd].write "500 Illegal username\r\n"
      @name = nil
      return 0
    end
    @connected = true
    @cs[:cmd].write "230 User #{args} logged in.\r\n"
    0
  end

  def ftp_type(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    @cs[:cmd].write "200 Type set to #{args.strip!} but everything's same for me !\r\n"
    0
  end

  def ftp_list(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    # if (s = get_data_connection).nil?
    #   return ftp_425(c, args)
    # end
    if not (s = get_data_socket) == 0
      return ftp_425(c, args)
    end
    res = ""
    Dir.entries(@yml['ftp']['root_folder'] + args.strip!).each do |entry|
      res << entry << "\r\n"
    end
    @cs[:data].write(res)
    # ftp_502 c, args
    0
  end

  def ftp_pasv(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    (@yml['ftp']['data_port_min']..@yml['ftp']['data_port_max']).each do |port|
      begin
        @cs[:data_accept] = TCPServer.new(port)
        @data_port = port
      rescue SystemCallError
      rescue
        puts e.message
        puts "Something goes very bad in PASV command"
        return -1
      end
    end
    if @yml['ftp'].include?('public_ip') and not @yml['ftp']['public_ip'].nil?
      ip = @yml['ftp']['public_ip']
    else
      ip = @cs[:cmd].addr.last
    end
    ip[/(\d+)\.(\d+)\.(\d+)\.(\d+)/]
    p1 = @data_port / 256
    p2 = @data_port % 256
    @cs[:cmd].write "227 Entering Passive Mode (#{$1},#{$2},#{$3},#{$4},#{p1},#{p2})\r\n"
    0
  end

  def ftp_pwd(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    @cs[:cmd].write("257 \"#{@wd}\" is current directory.\r\n")
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

  def welcome
    return  "220-\r\n\r\n Welcome to Fuji FTP server !\r\n\r\n
 ______     _ _   ______ _______ _____  \r\n
|  ____|   (_|_) |  ____|__   __|  __ \ \r\n
| |__ _   _ _ _  | |__     | |  | |__) |\r\n
|  __| | | | | | |  __|    | |  |  ___/ \r\n
| |  | |_| | | | | |       | |  | |     \r\n
|_|   \__,_| |_| |_|       |_|  |_|     \r\n
          _/ |                          \r\n
         |__/                           \r\n
220 Connected\r\n
"
  end

  def run
    puts "[#{Process.pid}] Instanciating connection from #{@cs[:cmd].peeraddr[2]}:#{@cs[:cmd].peeraddr[1]}"
    peeraddr = @cs[:cmd].peeraddr.dup
    @cs[:cmd].write welcome
    until @cs[:cmd].closed?
      rs = IO.select(@cs.values_not_nil_in_array)
      if not rs.nil?
        if rs[0].include?(@cs[:cmd])
          line = @cs[:cmd].gets
          if line.nil?
            break
          end
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
        if rs[0].include?(@cs[:data_accept])
          ####
          # passive data socket
          ####
          if not do_data_accept == 0
            break
          end
          puts "passive data socket"
          Kernel.exit -1
        end
      end
    end
    puts "[#{Process.pid}] Killing connection from #{peeraddr[2]}:#{peeraddr[1]}"
    if not @cs[:cmd].closed?
      @cs[:cmd].close
    end
  end

end

