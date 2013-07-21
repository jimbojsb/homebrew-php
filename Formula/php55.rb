require 'formula'
require 'net/http'

class Php55 < Formula
  url 'http://us2.php.net/get/php-5.5.1.tar.gz/from/us1.php.net/mirror'
  sha1 '401978b63c9900b8b33e1b70ee2c162e636dbf42'
  homepage 'http://php.net/'
  version '5.5.1.01'

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
  depends_on 'wget'
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
      "--with-zlib=#{Formula.factory('homebrew/dupes/zlib').opt_prefix}",
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

    File.delete(etc+"php.ini") rescue nil
    File.delete(etc+"php-cli.ini") rescue nil
    File.delete(etc+"php-fpm.conf") rescue nil
    `rm -fR #{HOMEBREW_PREFIX}/lib/php`

    install_xquartz

    args = install_args
    File.delete("configure")
    system "./buildconf --force"
    system "./configure", *args
    system "make"
    system "make install"

    etc.install "./php.ini-development" => "php.ini"
    (etc+'php-fpm.conf').write php_fpm_conf
    (etc+'php-fpm.conf').chmod 0644
    plist_path.write php_fpm_startup_plist
    plist_path.chmod 0644
   
    set_ini_defaults

    system "chmod -R 755 #{lib}"

  end

  def post_install
    install_extensions
    install_composer
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
    ohai "downloading xquartz"
    Net::HTTP.start('xquartz.macosforge.org') {
      |http|
      resp = http.get("/downloads/SL/XQuartz-2.7.4.dmg")
      open("/tmp/xquartz.dmg", "wb") {
        |file|
        file.write(resp.body)
      }
    }
    ohai "installing xquartz"
    `hdiutil attach /tmp/xquartz.dmg`
    `sudo /usr/sbin/installer -pkg /Volumes/XQuartz-2.7.4/XQuartz.pkg -target /`
    ohai "cleaning up xquartz"
    `hdituil detach /Volumes/XQuartz-2.7.4`
    `rm -fR /tmp/xquartz.dmg`
  end

  def install_extensions
    ohai "installing aop"  
    system "wget http://pecl.php.net/get/AOP-0.2.2b1.tgz && tar -zxvf AOP-0.2.2b1.tgz && cd AOP-0.2.2b1 && #{bin}/phpize && ./configure && make && cp modules/aop.so #{lib}/php/extensions/no-debug-non-zts-20121212 && cd ../ && rm -fR AOP-0.2.2b1*"

    ohai "installing mongo"  
    system "wget http://pecl.php.net/get/mongo-1.4.1.tgz && tar -zxvf mongo-1.4.1.tgz && cd mongo-1.4.1 && #{bin}/phpize && ./configure && make && cp modules/mongo.so #{lib}/php/extensions/no-debug-non-zts-20121212 && cd ../ && rm -fR mongo-1.4.1*"

    ohai "installing markdown"  
    system "wget http://pecl.php.net/get/markdown-1.0.0.tgz && tar -zxvf markdown-1.0.0.tgz && cd markdown-1.0.0 && #{bin}/phpize && ./configure && make && cp modules/discount.so #{lib}/php/extensions/no-debug-non-zts-20121212 && cd ../ && rm -fR markdown-1.0.0*"

    ohai "installing imagick"
    system "wget http://pecl.php.net/get/imagick-3.1.0RC2.tgz && tar -zxvf imagick-3.1.0RC2.tgz && cd imagick-3.1.0RC2 && sed -i '' 's/include\\/ImageMagick/include\\/ImageMagick-6/' config.m4 && autoconf --force && #{bin}/phpize && ./configure && make && cp modules/imagick.so #{lib}/php/extensions/no-debug-non-zts-20121212 && cd ../ && rm -fR imagick-3.1.0RC2*"

    ohai "installing xdebug"
    system "wget http://pecl.php.net/get/xdebug-2.2.3.tgz && tar -zxvf xdebug-2.2.3.tgz && cd xdebug-2.2.3 && #{bin}/phpize && ./configure && make && cp modules/xdebug.so #{lib}/php/extensions/no-debug-non-zts-20121212 && cd ../ && rm -fR xdebug-2.2.3*"

    ohai "activating extensions"
    inreplace (etc+"php.ini") do |s|
      s << "mongo.native_long=1\n"
      s << "zend_extension=#{lib}/php/extensions/no-debug-non-zts-20121212/xdebug.so\n"
      s << "xdebug.remote_host=localhost\n"
      s << "xdebug.remote_enable=1\n"
      s << "extension=aop.so\n"
      s << "extension=mongo.so\n"
      s << "extension=discount.so\n"
      s << "extension=imagick.so\n"
    end

    inreplace (File.expand_path("~")+"/.bash_profile") do |s|
      s.gsub! "alias phpd=\"php -d xdebug.remote_autostart=1\"\n", "" rescue nil
      s << "alias phpd=\"php -d xdebug.remote_autostart=1\"\n"
    end
  end

  def set_ini_defaults
    inreplace (etc+"php.ini") do |s|
      ohai "setting defaults"
      s.gsub! "short_open_tag = Off", "short_open_tag = On"
      s.gsub! ";date.timezone =", "date.timezone = America/Chicago"
      s.gsub! "error_reporting = E_ALL", "error_reporting = E_ALL & ~(E_NOTICE | E_DEPRACATED | E_STRICT)"
      s.gsub! "memory_limit = 128M", "memory_limit = 512M"
    end

    system "cp #{etc}/php.ini #{etc}/php-cli.ini"
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