require 'formula'
require 'net/http'

class Php < Formula
  url 'http://us1.php.net/get/php-5.4.14.tar.gz/from/this/mirror'
  sha1 '08d914996ae832e027b37f6a709cd9e04209c005'
  homepage 'http://php.net/'
  version '5.4.14.03'

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
  depends_on 'imagemagick'
  depends_on 'pkg-config' => :build

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
      "--with-bz2",
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
      "--mandir=#{man}"
    ]
    args
  end

  def install

    File.delete(etc+"php.ini") unless !File.exists? etc+"php.ini"
    File.delete(etc+"php-cli.ini") unless !File.exists? etc+"php-cli.ini"
    File.delete(etc+"php-fpm.conf") unless !File.exists? etc+"php-fpm.conf"

    install_xquartz

    args = install_args
    system "./configure", *args
    system "make", "-j4"
    ENV.deparallelize # parallel install fails on some systems
    system "make install"

    etc.install "./php.ini-development" => "php.ini" unless File.exists? etc+"php.ini"
    (etc+'php-fpm.conf').write php_fpm_conf unless File.exists? etc+"php-fpm.conf"
    (etc+'php-fpm.conf').chmod 0644
    plist_path.write php_fpm_startup_plist
    plist_path.chmod 0644

    install_mongo
    install_markdown
    install_aop
    install_xdebug
    install_apc
    install_imagick
    install_composer
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

      [www-debug]
      user = #{`whoami`.chomp}
      listen = /tmp/php-fpm-debug.sock
      pm = dynamic
      pm.max_children = 5
      pm.start_servers = 2
      pm.min_spare_servers = 1
      pm.max_spare_servers = 3
      php_admin_value[xdebug.remote_autostart]=1
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
    system "#{bin}/pecl", "install", "imagick-beta"
    inreplace (etc+"php.ini") do |s|
      s << "extension=imagick.so\n"
    end
  end

  def install_mongo
    system "#{bin}/pecl", "install", "mongo"
    inreplace (etc+"php.ini") do |s|
      s << "extension=mongo.so\n"
      s << "mongo.native_long=1\n"
    end
  end

  def install_aop
    system "#{bin}/pecl", "install", "aop-beta"
    inreplace (etc+"php.ini") do |s|
      s << "extension=aop.so\n"
    end
  end

  def install_markdown
    system "#{bin}/pecl", "install", "markdown"
    inreplace (etc+"php.ini") do |s|
      s << "extension=discount.so\n"
    end
  end 

  def install_apc
    system "#{bin}/pecl", "install", "apc-beta"
    inreplace (etc+"php.ini") do |s|
      s << "extension=apc.so\n"
    end
  end 

  def install_xdebug
    system "#{bin}/pecl", "install", "xdebug"
    inreplace (etc+"php.ini") do |s|
      s << "zend_extension=#{lib}/extensions/no-debug-non-zts-20100525/xdebug.so\n"
      s << "xdebug.remote_host=localhost\n"
      s << "xdebug.remote_enable=1\n"
    end
    inreplace (File.expand_path("~")+"/.bash_profile") do |s|
      s << 'alias phpd=php -d xdebug.remote_autostart=1'
    end
  end


  def fix_conf
    inreplace (etc+"php.ini") do |s|
      s.gsub! "short_open_tag = Off", "short_open_tag = On"
      s.gsub! ";date.timezone =", "date.timezone = America/Chicago"
      s.gsub! "error_reporting = E_ALL", "error_reporting = E_ALL & ~(E_NOTICE | E_DEPRACATED | E_STRICT)"
      s.gsub! "memory_limit = 128M", "memory_limit = 512M"
    end
    `cp #{etc}/php.ini #{etc}/php-cli.ini`
    inreplace (etc+"php-cli.ini") do |s|
      s.gsub! "memory_limit = 512", "memory_limit = -1"
    end

  end

  def install_composer
    if File.exists?("#{HOMEBREW_PREFIX}/bin/composer")
      `#{HOMEBREW_PREFIX}/bin/composer selfupdate`
    else
      `curl -sS https://getcomposer.org/installer | #{bin}/php`
      `mv composer.phar #{HOMEBREW_PREFIX}/bin/composer`
    end
  end
end
