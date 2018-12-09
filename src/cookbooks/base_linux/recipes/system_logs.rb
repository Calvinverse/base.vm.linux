# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: system_logs
#
# Copyright 2017, P. van der Velde
#

#
# INSTALL SYSLOG-NG
#

# For some reason gpg doesn't exist, so we install it?
apt_package 'gpg-agent' do
  action :install
end

apt_repository 'syslog-ng-apt-repository' do
  action :add
  distribution './'
  key 'http://download.opensuse.org/repositories/home:/laszlo_budai:/syslog-ng/xUbuntu_18.04/Release.key'
  uri 'http://download.opensuse.org/repositories/home:/laszlo_budai:/syslog-ng/xUbuntu_18.04'
end

# Installing the syslog-ng package automatically creates a systemd daemon and replaces the other
# syslog daemons
%w[syslog-ng-core syslog-ng-mod-amqp syslog-ng-mod-json].each do |pkg|
  apt_package pkg do
    action :install
    version '3.18.1-1'
  end
end

#
# CONFIGURATION
#

syslog_ng_config = "#{node['syslog_ng']['config_path']}/syslog-ng.conf"
syslog_ng_config_path = node['syslog_ng']['custom_config_path']
file syslog_ng_config do
  action :create
  content <<~CONF
    @version: 3.16
    @include "scl.conf"

    # Syslog-ng configuration file, compatible with default Debian syslogd
    # installation.

    # First, set some global options.
    options { chain_hostnames(off); flush_lines(0); use_dns(no); use_fqdn(no);
              owner("root"); group("adm"); perm(0640); stats_freq(0);
              bad_hostname("^gconfd$");
    };

    ########################
    # Sources
    ########################
    # Logs may come from unix stream, or from UDP. The firewall is not
    # configured to allow the port through so logs should still only
    # come from the local machine
    source s_src {
          system();
          internal();
          udp();
    };

    ########################
    # Destinations
    ########################
    # First some standard logfile
    #
    destination d_auth { file("/var/log/auth.log"); };
    destination d_cron { file("/var/log/cron.log"); };
    destination d_daemon { file("/var/log/daemon.log"); };
    destination d_kern { file("/var/log/kern.log"); };
    destination d_lpr { file("/var/log/lpr.log"); };
    destination d_mail { file("/var/log/mail.log"); };
    destination d_syslog { file("/var/log/syslog"); };
    destination d_user { file("/var/log/user.log"); };
    destination d_uucp { file("/var/log/uucp.log"); };

    # This files are the log come from the mail subsystem.
    #
    destination d_mailinfo { file("/var/log/mail.info"); };
    destination d_mailwarn { file("/var/log/mail.warn"); };
    destination d_mailerr { file("/var/log/mail.err"); };

    # Logging for INN news system
    #
    destination d_newscrit { file("/var/log/news/news.crit"); };
    destination d_newserr { file("/var/log/news/news.err"); };
    destination d_newsnotice { file("/var/log/news/news.notice"); };

    # Some 'catch-all' logfiles.
    #
    destination d_debug { file("/var/log/debug"); };
    destination d_error { file("/var/log/error"); };
    destination d_messages { file("/var/log/messages"); };

    # The root's console.
    #
    destination d_console { usertty("root"); };

    # Virtual console.
    #
    destination d_console_all { file(`tty10`); };

    # The named pipe /dev/xconsole is for the nsole' utility.  To use it,
    # you must invoke nsole' with the -file' option:
    #
    #    $ xconsole -file /dev/xconsole [...]
    #
    destination d_xconsole { pipe("/dev/xconsole"); };

    # Send the messages to an other host
    #
    #destination d_net { tcp("127.0.0.1" port(1000) log_fifo_size(1000)); };

    # Debian only
    destination d_ppp { file("/var/log/ppp.log"); };

    ########################
    # Filters
    ########################
    # Here's come the filter options. With this rules, we can set which
    # message go where.

    filter f_dbg { level(debug); };
    filter f_info { level(info); };
    filter f_notice { level(notice); };
    filter f_warn { level(warn); };
    filter f_err { level(err); };
    filter f_crit { level(crit .. emerg); };

    filter f_debug { level(debug) and not facility(auth, authpriv, news, mail); };
    filter f_error { level(err .. emerg) ; };
    filter f_messages { level(info,notice,warn) and
                        not facility(auth,authpriv,cron,daemon,mail,news); };

    filter f_auth { facility(auth, authpriv) and not filter(f_debug); };
    filter f_cron { facility(cron) and not filter(f_debug); };
    filter f_daemon { facility(daemon) and not filter(f_debug); };
    filter f_kern { facility(kern) and not filter(f_debug); };
    filter f_lpr { facility(lpr) and not filter(f_debug); };
    filter f_local { facility(local0, local1, local3, local4, local5,
                            local6, local7) and not filter(f_debug); };
    filter f_mail { facility(mail) and not filter(f_debug); };
    filter f_news { facility(news) and not filter(f_debug); };
    filter f_syslog3 { not facility(auth, authpriv, mail) and not filter(f_debug); };
    filter f_user { facility(user) and not filter(f_debug); };
    filter f_uucp { facility(uucp) and not filter(f_debug); };

    filter f_cnews { level(notice, err, crit) and facility(news); };
    filter f_cother { level(debug, info, notice, warn) or facility(daemon, mail); };

    filter f_ppp { facility(local2) and not filter(f_debug); };
    filter f_console { level(warn .. emerg); };

    ########################
    # Log paths
    ########################
    log { source(s_src); filter(f_auth); destination(d_auth); };
    log { source(s_src); filter(f_cron); destination(d_cron); };
    log { source(s_src); filter(f_daemon); destination(d_daemon); };
    log { source(s_src); filter(f_kern); destination(d_kern); };
    log { source(s_src); filter(f_lpr); destination(d_lpr); };
    log { source(s_src); filter(f_syslog3); destination(d_syslog); };
    log { source(s_src); filter(f_user); destination(d_user); };
    log { source(s_src); filter(f_uucp); destination(d_uucp); };

    log { source(s_src); filter(f_mail); destination(d_mail); };
    #log { source(s_src); filter(f_mail); filter(f_info); destination(d_mailinfo); };
    #log { source(s_src); filter(f_mail); filter(f_warn); destination(d_mailwarn); };
    #log { source(s_src); filter(f_mail); filter(f_err); destination(d_mailerr); };

    log { source(s_src); filter(f_news); filter(f_crit); destination(d_newscrit); };
    log { source(s_src); filter(f_news); filter(f_err); destination(d_newserr); };
    log { source(s_src); filter(f_news); filter(f_notice); destination(d_newsnotice); };
    #log { source(s_src); filter(f_cnews); destination(d_console_all); };
    #log { source(s_src); filter(f_cother); destination(d_console_all); };

    #log { source(s_src); filter(f_ppp); destination(d_ppp); };

    log { source(s_src); filter(f_debug); destination(d_debug); };
    log { source(s_src); filter(f_error); destination(d_error); };
    log { source(s_src); filter(f_messages); destination(d_messages); };

    log { source(s_src); filter(f_console); destination(d_console_all);
                                        destination(d_xconsole); };
    log { source(s_src); filter(f_crit); destination(d_console); };

    # All messages send to a remote site
    #
    #log { source(s_src); destination(d_net); };

    ###
    # Include all config files in /etc/syslog-ng/conf.d/
    ###
    @include "#{syslog_ng_config_path}/*.conf"
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

directory syslog_ng_config_path do
  action :create
end

#
# CONSUL TEMPLATE FILES
#

consul_template_template_path = node['consul_template']['template_path']
consul_template_config_path = node['consul_template']['config_path']

# Create the consul-template template file
syslog_ng_template_file = node['syslog_ng']['consul_template_file']
file "#{consul_template_template_path}/#{syslog_ng_template_file}" do
  action :create
  content <<~CONF
    @version: 3.18

    ########################
    # Destinations
    ########################
    # The RabbitMQ destination
    destination d_rabbit_syslog {
      amqp(
        body("$(format-json date=datetime($ISODATE) pid=$PID program=$PROGRAM message=$MESSAGE facility=$FACILITY host=$FULLHOST priorityNum=int64($LEVEL_NUM) priority=$LEVEL)")
        exchange("{{ keyOrDefault "config/services/queue/logs/syslog/exchange" "" }}")
        exchange-type("direct")
        host("{{ keyOrDefault "config/services/queue/protocols/amqp/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "consul" }}")
        port({{ keyOrDefault "config/services/queue/protocols/amqp/port" "80" }})
        routing-key("syslog")
        vhost("{{ keyOrDefault "config/services/queue/logs/syslog/vhost" "logs" }}")

    {{ with secret "secret/services/queue/users/logs/syslog" }}
      {{ if .Data.password }}
        password("{{ .Data.password }}")
        username("{{ .Data.username }}")
      {{ end }}
    {{ end }}
      );
    };

    ########################
    # Log paths
    ########################

    log { source(s_src); filter(f_syslog3); destination(d_rabbit_syslog); };
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

# Create the consul-template configuration file
syslog_ng_config_file = node['syslog_ng']['config_file']
file "#{consul_template_config_path}/syslog-ng.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{syslog_ng_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{syslog_ng_config_path}/#{syslog_ng_config_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "systemctl restart syslog-ng"

      # This is the maximum amount of time to wait for the optional command to
      # return. Default is 30s.
      command_timeout = "15s"

      # Exit with an error when accessing a struct or map field/key that does not
      # exist. The default behavior will print "<no value>" when accessing a field
      # that does not exist. It is highly recommended you set this to "true" when
      # retrieving secrets from Vault.
      error_on_missing_key = false

      # This is the permission to render the file. If this option is left
      # unspecified, Consul Template will attempt to match the permissions of the
      # file that already exists at the destination path. If no file exists at that
      # path, the permissions are 0644.
      perms = 0550

      # This option backs up the previously rendered template at the destination
      # path before writing a new one. It keeps exactly one backup. This option is
      # useful for preventing accidental changes to the data without having a
      # rollback strategy.
      backup = true

      # These are the delimiters to use in the template. The default is "{{" and
      # "}}", but for some templates, it may be easier to use a different delimiter
      # that does not conflict with the output file itself.
      left_delimiter  = "{{"
      right_delimiter = "}}"

      # This is the `minimum(:maximum)` to wait before rendering a new template to
      # disk and triggering a command, separated by a colon (`:`). If the optional
      # maximum value is omitted, it is assumed to be 4x the required minimum value.
      # This is a numeric time with a unit suffix ("5s"). There is no default value.
      # The wait value for a template takes precedence over any globally-configured
      # wait.
      wait {
        min = "2s"
        max = "10s"
      }
    }
  HCL
  group 'root'
  mode '0550'
  owner 'root'
end
