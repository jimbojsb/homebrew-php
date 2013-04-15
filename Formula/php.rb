require 'formula'
require 'net/http'

class Php < Formula
  url 'http://us1.php.net/get/php-5.4.14.tar.gz/from/this/mirror'
  sha1 '08d914996ae832e027b37f6a709cd9e04209c005'
  homepage 'http://php.net/'
  version '5.4.14'

  # Leopard requires Hombrew OpenSSL to build correctly
  depends_on 'openssl'
  depends_on 'libxml2'
  depends_on 'homebrew/dupes/zlib'
  depends_on 'jpeg'
  depends_on 'libpng'
  depends_on 'freetype'
  depends_on 'imap-uw'
  depends_on 'curl'
  depends_on 'libvpx'
  depends_on 'autoconf'

  option 'with-wipe-config', "Kill all existing config files"

def install_args
    args = [
      "--prefix=#{prefix}",
      "--localstatedir=#{var}",
      "--sysconfdir=#{etc}",
      "--with-config-file-path=#{etc}",
      "--with-iconv-dir=/usr",
      "--enable-exif",
      "--enable-soap",
      "--enable-wddx",
      "--enable-ftp",
      "--enable-sockets",
      "--enable-zip",
      "--enable-pcntl",
      "--enable-mbstring",
      "--enable-mbregex",
      "--enable-bcmath",
      "--enable-calendar",
      "--with-zlib=#{Formula.factory('zlib').opt_prefix}",
      "--with-xmlrpc",
      "--with-mysqli=mysqlnd",
      "--with-mysql=mysqlnd",
      "--with-pdo-mysql=mysqlnd",
      "--with-curl=#{Formula.factory('curl').opt_prefix}",
      "--enable-fpm",
      "--with-openssl=" + Formula.factory('openssl').opt_prefix.to_s,
      "--with-imap=#{Formula.factory('imap-uw').opt_prefix}",
      "--with-imap-ssl=#{Formula.factory('imap-uw').opt_prefix}",
      "--with-kerberos",
      "--with-kerberos=/usr",
      "--with-gd",
      "--enable-gd-native-ttf",
      "--with-freetype-dir=#{Formula.factory('freetype').opt_prefix}",
      "--with-jpeg-dir=#{Formula.factory('jpeg').opt_prefix}",
      "--with-png-dir=#{Formula.factory('libpng').opt_prefix}",
      "--mandir=#{man}",
    ]
    args
  end

  def install

    if build.with? 'wipe-config'
      File.delete(etc+"php.ini") unless !File.exists? etc+"php.ini"
      File.delete(etc+"php-cli.ini") unless !File.exists? etc+"php-cli.ini"
      File.delete(etc+"php-fpm.conf") unless !File.exists? etc+"php-fpm.conf"
    end

    plist_path.write php_fpm_startup_plist
    plist_path.chmod 0644

    install_xquartz

    args = install_args
    system "./configure", *args
    system "make"
    ENV.deparallelize # parallel install fails on some systems
    system "make install"

    etc.install "./php.ini-development" => "php.ini" unless File.exists? etc+"php.ini"
    (etc+'php-fpm.conf').write php_fpm_conf unless File.exists? etc+"php-fpm.conf"
    (etc+'php-fpm.conf').chmod 0644

    chmod_R 0775, lib+"php"

    system bin+"pear", "config-set", "php_ini", etc+"php.ini"

    install_mongo
    fix_conf
  end

  def php_fpm_startup_plist; <<-EOPLIST.undent
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
        <true/>
        <key>Label</key>
        <string>homebrew.mcxl.php</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{sbin}/php-fpm</string>
          <string>--fpm-config</string>
          <string>#{etc}/php-fpm.conf</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>LaunchOnlyOnce</key>
        <true/>
        <key>UserName</key>
        <string>#{`whoami`.chomp}</string>
        <key>WorkingDirectory</key>
        <string>#{var}</string>
      </dict>
      </plist>
      EOPLIST
  end 

  def php_fpm_conf; <<-EOCONF.undent
      [global]
      pid = #{var}/run/php-fpm.pid
      error_log = #{var}/log/php/php-fpm.log
      daemonize = no
       
      [www]
      user = #{`whoami`.chomp}
      listen = /tmp/php-fpm.sock
      pm = dynamic
      pm.max_children = 5
      pm.start_servers = 2
      pm.min_spare_servers = 1
      pm.max_spare_servers = 3
    EOCONF
  end

  def install_xquartz
    return if File.directory?("/opt/X11")
    puts "downloading xquartz"
    Net::HTTP.start('xquartz.macosforge.org') {
      |http|
      resp = http.get("/downloads/SL/XQuartz-2.7.4.dmg")
      open("/tmp/xquartz.dmg", "wb") {
        |file|
        file.write(resp.body)
      }
    }
    puts "installing xquartz"
    `hdiutil attach /tmp/xquartz.dmg`
    `sudo /usr/sbin/installer -pkg /Volumes/XQuartz-2.7.4/XQuartz.pkg -target /`
    puts "cleaning up xquartz"
    `hdituil detach /Volumes/XQuartz-2.7.4`
    `rm -fR /tmp/xquartz.dmg`
    puts "done with xquartz"
  end

  def install_imagick

  end

  def install_mongo
    system bin+"pecl", "install", "mongo"
  end

  def install_markdown

  end

  def install_aop

  end

  def fix_conf
    if build.with? "wipe-config"
      inreplace (etc+"php.ini") do |s|
        s.gsub! "short_open_tag = Off", "short_open_tag = On"
        s.gsub! ";date.timezone =", "date.timezone = America/Chicago"
        s.gsub! "error_reporting = E_ALL", "error_reporting = E_ALL & ~(E_NOTICE | E_DEPRACATED | E_STRICT)"
        s << "mongo.native_long=1\n"
      end
    end
  end

end
