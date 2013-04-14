require 'formula'

class Php54 < Formula
  init
  url 'http://us1.php.net/get/php-5.4.14.tar.gz/from/this/mirror'
  sha1 'f34a01fd3af20f19aae1788760e089d987ded15b'
  version '5.4.14'

  # Leopard requires Hombrew OpenSSL to build correctly
  depends_on 'openssl'
  depends_on 'libxml2'


def install_args
    args = [
      "--prefix=#{prefix}",
      "--localstatedir=#{var}",
      "--sysconfdir=#{config_path}",
      "--with-config-file-path=#{config_path}",
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
      "--with-kerberos"
      "--with-kerberos=/usr",
      "--with-gd",
      "--enable-gd-native-ttf",
      "--with-freetype-dir=#{Formula.factory('freetype').opt_prefix}",
      "--with-jpeg-dir=#{Formula.factory('jpeg').opt_prefix}",
      "--with-png-dir=#{Formula.factory('libpng').opt_prefix}",
      "--with-gettext=#{Formula.factory('gettext').opt_prefix}",
      "--mandir=#{man}",
    ]
    args
  end

  def _install
    args = install_args

    (prefix+'var/log').mkpath
    touch prefix+'var/log/php-fpm.log'
    (prefix+"homebrew.mxcl.php-fpm.plist").write php_fpm_startup_plist
    (prefix+"homebrew.mxcl.php-fpm.plist").chmod 0644

    system "./configure", *args

    system "make"
    ENV.deparallelize # parallel install fails on some systems
    system "make install"

    config_path.install "./php.ini-development" => "php.ini" unless File.exists? config_path+"php.ini"

    chmod_R 0775, lib+"php"

    system bin+"pear", "config-set", "php_ini", config_path+"php.ini" unless skip_pear_config_set?

    (config_path+"php-fpm.conf").write php_fpm_conf
    (config_path+"php-fpm.conf").chmod 0644
  end

  def php_fpm_startup_plist; <<-EOPLIST.undent
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
        <true/>
        <key>Label</key>
        <string>homebrew.mcxl.php-fpm</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{sbin}/php-fpm</string>
          <string>--fpm-config</string>
          <string>#{config_path}/php-fpm.conf</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>LaunchOnlyOnce</key>
        <true/>
        <key>UserName</key>
        <string>#{`whoami`.chomp}</string>
        <key>WorkingDirectory</key>
        <string>#{var}</string>
        <key>StandardErrorPath</key>
        <string>#{prefix}/var/log/php-fpm.log</string>
      </dict>
      </plist>
      EOPLIST
  end 

  def php_fpm_conf; <<-EOCONF.undent
      [global]
      pid = #{prefix}/var/run/php-fpm.pid
      error_log = #{prefix}var/log/php/php-fpm.log
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
