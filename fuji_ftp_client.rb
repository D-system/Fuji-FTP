
require "socket"
include Socket::Constants
load "hash_class_eval.rb"
require 'rubygems'
gem 'datamapper', '=1.1.0'
gem 'dm-core', '=1.1.0'
gem 'dm-mongo-adapter'
load 'collections.rb'

# Handle each client
class FujiFtpClient
  def initialize(socket, yml)
    @cs = {:cmd => socket, :data_accept => nil, :data => nil}
    @yml = yml
    @connected = @yml['ftp']['anonymous']
    @name = nil
    @wd = @yml['ftp']['root_folder']
    @passive = nil
    @data_port = nil
    @data_socket = nil
    @log = LogInOut.create(:time_in => Time.now)
    @log.save
  end

  def destrotor
    @cs[:cmd].close if not @cs[:cmd].closed?
    @log.update(:time_out => Time.now,
                :duration => Time.now.to_time.to_i - @log['time_in'].to_time.to_i)
  end

  def get_data_socket
    if @passive.nil?
      ftp_425
      return false
    end
    if @passive
      if not @cs[:data].nil?
        return @cs[:data]
      end
      if do_data_accept
        return @cs[:data]
      else
        return false
      end
    else
      puts "get_data_socket active connection !"
      ####
      # connect to client
      ####
      return false
    end
    false
  end

  def do_data_accept
    begin
      if IO.select([@cs[:data_accept]], nil, nil, 20).nil?
        puts "Can't accept data connection, timeout"
        ftp_425
        return false
      end
      @cs[:data] = @cs[:data_accept].accept_nonblock
      @cs[:cmd].write "150 data connection opened\r\n"
      return true
    rescue SystemCallError => e
      p e
      puts "Can't accept data connection"
      ftp_425
      return false
    rescue
      puts e.message
      puts "Something goes very bad to get data coonection"
      return false
    end
  end

  def send_data(data, multi_send = false)
    if get_data_socket == false
      return false
    end
    sd = @cs[:data].write data
    if multi_send == false or (multi_send == true and data.size == 0)
      @cs[:data].close
      @cs[:data] = nil
      @cs[:cmd].write "226 Transfer complete.\r\n"
    end
    sd
  end

  def get_realpath(path)
    begin
      res = File.realpath(path).to_s
    rescue => e
      p e
      return nil
    end
    if not res[0..@yml['ftp']['root_folder'].size - 1] == @yml['ftp']['root_folder']
      return nil
    end
    return res
  end

  def get_realdirpath(path)
    begin
      res = File.realdirpath(path).to_s
    rescue => e
      p e
      return nil
    end
    if not res[0..@yml['ftp']['root_folder'].size - 1] == @yml['ftp']['root_folder']
      return @yml['ftp']['root_folder']
    end
    return res
  end

  def ftp_425(c = nil, args = nil)
    @cs[:cmd].write "425 Can't open data connection.\r\n"
    0
  end

  def ftp_500(c, args = nil)
    puts "'#{c}' command unrecognized"
    @cs[:cmd].write "500 '#{c}' command unrecognized\r\n"
    0
  end

  def ftp_501(c = nil, args = nil)
    @cs[:cmd].write "501 Syntax error in parameters or arguments.\r\n"
    0
  end

  def ftp_502(c = "", args = nil)
    puts "Command '#{c}' not implemented"
    @cs[:cmd].write "502 Command '#{c}' not implemented\r\n"
    0
  end

  def ftp_503(c = nil, args = nil)
    @cs[:cmd].write "503 Bad sequence of commands.\r\n"
    0
  end

  def ftp_530(c = nil, args = nil)
    @cs[:cmd].write "530 Not logged in.\r\n"
    0
  end

  def ftp_550(c = nil, args = nil)
    @cs[:cmd].write "550 File unavailable.\r\n"
    0
  end

  def ftp_551(c = nil, args = nil)
    @cs[:cmd].write "551 Requested action aborted.\r\n"
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
    if @yml['ftp']['anonymous'] == true
      @connected = true
      @cs[:cmd].write "230 User #{args} logged in.\r\n"
      return 0
    end
    @connected = false
    @name = nil
    if not @yml['ftp']['users'].has_key?(args)
      @cs[:cmd].close
      return -1
    end
    @name = args
    @cs[:cmd].write "331 User name okay, need password.\r\n"
    0
  end

  def ftp_pass(c, args)
    if @name.nil?
      return ftp_503(c, args)
    end
    if @yml['ftp']['anonymous'] == true
      @connected = true
      @cs[:cmd].write "230 User #{args} logged in.\r\n"
      return 0
    end
    if not @yml['ftp']['users'][@name] == args
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
    @cs[:cmd].write "200 Type set to #{args} but everything's same for me !\r\n"
    0
  end

  def _ftp_list_mode(p_name, mode)
    if p_name.symlink?
      res = "l"
    elsif p_name.directory?
      res = "d"
    else
      res = "-"
    end
    mode[/(\d)(\d)(\d)$/]
    mode[mode.size - 3..mode.size - 1].each_char do |c|
      if c == '7'
        res += 'rwx'
      elsif c == '6'
        res += 'rw-'
      elsif c == '5'
        res += 'r-x'
      elsif c == '4'
        res += 'r--'
      elsif c == '3'
        res += '-wx'
      elsif c == '2'
        res += '-w-'
      elsif c == '1'
        res += '--x'
      elsif c == '0'
        res += '---'
      end
    end
    res
  end

  def ftp_list(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    if (pwd = get_realdirpath(@wd + '/' + args)).nil?
      ftp_551
      return 0
    end
    res = ""
    Dir.new(pwd).sort.each do |f_name|
      f = Pathname.new(pwd + '/' + f_name)
      mode = _ftp_list_mode(f, sprintf("%o", f.stat.mode))
      link = f.stat.nlink.to_s
      uid = Etc.getpwuid(f.stat.uid).name
      gid =  Etc.getpwuid(f.stat.gid).name
      size = f.stat.size.to_s
      time = f.stat.ctime.strftime("%b %e %H:%M")
      res += "#{mode} #{link} #{uid} #{gid} #{size} #{time} #{f_name}\r\n"
    end
    send_data(res)
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
        break
      rescue SystemCallError
      rescue
        puts e.message
        puts "Something goes very bad in PASV command"
        return -1
      end
    end
    # get public_ip from file configuration or ip of computeur
    if @yml['ftp'].include?('public_ip') and not @yml['ftp']['public_ip'].nil?
      ip = @yml['ftp']['public_ip']
    else
      ip = @cs[:cmd].addr.last
    end
    ip[/(\d+)\.(\d+)\.(\d+)\.(\d+)/]
    p1 = @data_port / 256
    p2 = @data_port % 256
    @cs[:cmd].write "227 Entering Passive Mode (#{$1},#{$2},#{$3},#{$4},#{p1},#{p2})\r\n"
    @passive = true
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
    ####
    # todo : all
    ####
    ftp_502 c, args
    0
  end

  def ftp_retr(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    path = @wd + '/' + args
    if (f_name = get_realpath(path)).nil?
      ftp_550
      return false
    end
    f = File.open(f_name, 'r')
    sended = 0
    begin
      until (data = f.read(1024)).nil?
        sended += send_data(data, true)
      end
    send_data ""
    rescue => e
      puts e.message
      puts "Error happen while sending data to client"
    end
    Transfer.create(:file_name => f_name.to_s,
                    :file_size => f.size,
                    :size_send => sended,
                    :logInOut => @log,
                    )
    f.close
    0
  end

  def ftp_cwd(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    if args[0] == '/'
      tmp = args
    elsif (tmp = get_realdirpath(@wd + '/' + args)).nil?
      tmp = @yml['ftp']['root_folder']
    end
    @wd = tmp
    @cs[:cmd].write "250 CWD command successful.\r\n"
    0
  end

  def ftp_cdup(c, args)
    if not @connected
      return ftp_530(c, args)
    end
    if (tmp = get_realdirpath(@wd + '/..')).nil?
      tmp = @yml['ftp']['root_folder']
    end
    @wd = tmp
    @cs[:cmd].write "200 directory changed to #{@wd}\r\n"
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
          ####
          # Handle commands here
          ####
          line.strip!
          puts "[#{Process.pid}] Client sent : --#{line}--"
          begin
            func = method('ftp_' + line[/[\s]*([\w]*)[\s]*(.*)/, 1].downcase);
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
          do_data_accept
        end
      end
    end
    puts "[#{Process.pid}] Killing connection from #{peeraddr[2]}:#{peeraddr[1]}"
    destrotor
  end

end

