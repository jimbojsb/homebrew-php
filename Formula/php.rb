require 'formula'

class Php < Formula
  url 'http://php.net/get/php-5.6.11.tar.gz/from/this/mirror'
  sha256 '85916b46c0d1f2a5315c84fb2773293f4084c3676ba4ed420d0432cbb60ff9d8'
  homepage 'http://php.net/'
  version '5.6.11.0'

  # Leopard requires Hombrew OpenSSL to build correctly
  depends_on 'openssl'
  depends_on 'homebrew/dupes/zlib'
  depends_on 'jpeg'
  depends_on 'libpng'
  depends_on 'freetype'
  depends_on 'imap-uw'
  depends_on 'curl'
  depends_on 'mcrypt'
  depends_on 'libvpx'
  depends_on 'libevent'
  depends_on 'libmemcached'
  depends_on 'autoconf' => :build
  depends_on 'imagemagick'
  depends_on 'freetds' => 'enable-msdblib'
  depends_on 'pkg-config' => :build
  depends_on 'wget' => :build

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
      "--with-zlib=#{Formula['homebrew/dupes/zlib'].opt_prefix}",
      "--with-xmlrpc",
      "--with-mysqli=mysqlnd",
      "--with-mysql=mysqlnd",
      "--with-mcrypt",
      "--with-mssql",
      "--with-pdo-mysql=mysqlnd",
      "--with-curl=#{Formula['curl'].opt_prefix}",
      "--enable-fpm",
      "--with-openssl=#{Formula['openssl'].opt_prefix}",
      "--with-imap=#{Formula['imap-uw'].opt_prefix}",
      "--with-imap-ssl=#{Formula['imap-uw'].opt_prefix}",
      "--with-kerberos",
      "--with-kerberos=/usr",
      "--with-gd",
      "--enable-gd-native-ttf",
      "--with-freetype-dir=#{Formula['freetype'].opt_prefix}",
      "--with-jpeg-dir=#{Formula['jpeg'].opt_prefix}",
      "--with-png-dir=#{Formula['libpng'].opt_prefix}",
      "--mandir=#{man}"
    ]
    args
  end

  def install

    File.delete(etc+"php.ini") rescue nil
    File.delete(etc+"php-cli.ini") rescue nil
    File.delete(etc+"php-fpm.conf") rescue nil
    `rm -fR #{HOMEBREW_PREFIX}/lib/php`

    args = install_args
    system "./configure", *args
    system "make"
    ENV.deparallelize
    system "make install"

    etc.install "./php.ini-development" => "php.ini"
    (etc+'php-fpm.conf').write php_fpm_conf
    (etc+'php-fpm.conf').chmod 0644

    `mkdir -p #{lib}/php/ext`
    install_xdebug
    install_markdown
    install_imagick
    install_mongo
    install_composer
    install_memcached
    fix_conf

    `chmod -R 755 #{lib}`

  end

  def safe_phpize
     cmd = ''
     cmd << "PHP_AUTOCONF=\"#{Formula.factory('autoconf').opt_prefix}/bin/autoconf\" "
     cmd << "PHP_AUTOHEADER=\"#{Formula.factory('autoconf').opt_prefix}/bin/autoheader\" "
     cmd << "#{bin}/phpize"

     system cmd
   end

  def plist; <<-EOPLIST.undent
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
        <true/>
        <key>Label</key>
        <string>homebrew.mxcl.php</string>
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
      listen.mode=0666
      pm.max_children = 5
      pm.start_servers = 2
      pm.min_spare_servers = 1
      pm.max_spare_servers = 3
      catch_workers_output = yes
    EOCONF
  end

  def install_imagick
    ohai "installing imagick"
    system "wget http://pecl.php.net/get/imagick-3.1.2.tgz"
    system "tar -zxvf imagick-3.1.2.tgz"
    Dir.chdir "imagick-3.1.2"
    system "#{bin}/phpize && ./configure --with-php-config=#{bin}/php-config && make && cp modules/imagick.so #{lib}/php/ext/imagick.so"
    inreplace (etc+"php.ini") do |s|
      s << "extension=imagick.so\n"
    end
  end

  def install_mongo
    ohai "installing mongo"
    system "wget http://pecl.php.net/get/mongo-1.4.5.tgz"
    system "tar -zxvf mongo-1.4.5.tgz"
    Dir.chdir "mongo-1.4.5"
    system "#{bin}/phpize && ./configure --with-php-config=#{bin}/php-config && make && cp modules/mongo.so #{lib}/php/ext/mongo.so"
    inreplace (etc+"php.ini") do |s|
      s << "extension=mongo.so\n"
      s << "mongo.native_long=1\n"
    end
  end

  def install_markdown
    ohai "installing markdown"
    system "wget http://pecl.php.net/get/markdown-1.0.0.tgz"
    system "tar -zxvf markdown-1.0.0.tgz"
    Dir.chdir "markdown-1.0.0"
    system "#{bin}/phpize && ./configure --with-php-config=#{bin}/php-config && make && cp modules/discount.so #{lib}/php/ext/discount.so"
    inreplace (etc+"php.ini") do |s|
      s << "extension=discount.so\n"
    end
  end

  def install_memcached
    ohai "installing memcached"
    system "wget http://pecl.php.net/get/memcached-2.2.0.tgz"
    system "tar -zxvf memcached-2.2.0.tgz"
    Dir.chdir "memcached-2.2.0"
    system "#{bin}/phpize && ./configure --with-php-config=#{bin}/php-config && make && cp modules/memcached.so #{lib}/php/ext/memcached.so"
    inreplace (etc+"php.ini") do |s|
      s << "extension=memcached.so\n"
    end
  end

  def install_xdebug
    ohai "installing xdebug"
    system "wget http://pecl.php.net/get/xdebug-2.2.4.tgz"
    system "tar -zxvf xdebug-2.2.4.tgz"
    Dir.chdir "xdebug-2.2.4"
    system "#{bin}/phpize && ./configure --with-php-config=#{bin}/php-config && make && cp modules/xdebug.so #{lib}/php/ext/xdebug.so"
    inreplace (etc+"php.ini") do |s|
      s << "zend_extension=#{lib}/php/ext/xdebug.so\n"
      s << "xdebug.remote_host=localhost\n"
      s << "xdebug.remote_enable=1\n"
    end
  end


  def fix_conf
    inreplace (etc+"php.ini") do |s|
      s.gsub! "short_open_tag = Off", "short_open_tag = On"
      s.gsub! ";date.timezone =", "date.timezone = America/Chicago"
      s.gsub! "error_reporting = E_ALL", "error_reporting = E_ALL & ~(E_NOTICE | E_DEPRECATED | E_STRICT)"
      s.gsub! "memory_limit = 128M", "memory_limit = 512M"
      s.gsub! "; extension_dir = \"ext\"", "extension_dir = \"#{lib}/php/ext\""
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
