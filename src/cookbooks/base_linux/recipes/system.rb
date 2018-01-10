# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: system
#
# Copyright 2017, P. van der Velde
#

#
# DISABLE THE UNATTEND UPDATE SERVICES
#
# Because they use apt which breaks the Packer build. These images are updated only once anyway. New updates
# will happen in a new image (see: https://github.com/boxcutter/ubuntu/issues/73#issuecomment-231679733)

systemd_unit 'apt-daily.service' do
  action %i[stop disable]
end

systemd_unit 'apt-daily.timer' do
  action %i[stop disable]
end

#
# INSTALL SYSLOG-NG
#

apt_repository 'syslog-ng-apt-repository' do
  action :add
  distribution './'
  key 'http://download.opensuse.org/repositories/home:/laszlo_budai:/syslog-ng/xUbuntu_16.04/Release.key'
  uri 'http://download.opensuse.org/repositories/home:/laszlo_budai:/syslog-ng/xUbuntu_16.04'
end

# Installing the syslog-ng package automatically creates a systemd daemon and replaces the other
# syslog daemons
%w[syslog-ng-core syslog-ng-mod-amqp syslog-ng-mod-json].each do |pkg|
  apt_package pkg do
    action :install
    version '3.10.1-1'
  end
end

syslog_ng_config_path = node['syslog_ng']['config_path']
directory syslog_ng_config_path do
  action :create
end

# Create the consul-template template file
syslog_ng_template_file = node['syslog_ng']['consul_template_file']
consul_template_template_path = node['consul_template']['template_path']
file "#{consul_template_template_path}/#{syslog_ng_template_file}" do
  action :create
  content <<~CONF
    ########################
    # Destinations
    ########################
    # The RabbitMQ destination
    destination d_rabbit {
      amqp(
        body("$(format-json date=datetime($ISODATE) pid=int64($PID) program=$PROGRAM message=$MESSAGE facility=$FACILITY host=$FULLHOST priorityNum=int64($LEVEL_NUM) priority=$LEVEL)")
        exchange("{{ keyOrDefault "config/services/queue/logs/syslog/exchange" "" }}"")
        exchange-type("direct")
        host("{{ keyOrDefault "config/services/queue/protocols/amqp/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "consul" }}")
    {{ with secret "secret/services/queue/logs/syslog"}}
      {{ if .Data.password }}
        password("{{ .Data.password }}")
      {{ end }}
    {{ end }}
        port({{ keyOrDefault "config/services/queue/protocols/amqp/port" "80" }})
        routing-key("syslog")
        username("{{ keyOrDefault "config/services/queue/logs/syslog/username" "logs" }}")
        vhost("{{ keyOrDefault "config/services/queue/logs/syslog/vhost" "logs" }}")
      );
    };

    ########################
    # Log paths
    ########################

    log { source(s_src); filter(f_syslog3); destination(d_rabbit); };
  CONF
  mode '755'
end

# Create the consul-template configuration file
syslog_ng_config_file = node['syslog_ng']['config_file']
consul_template_config_path = node['consul_template']['config_path']
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
      perms = 0755

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
  mode '755'
end

#
# DIRECTORIES
#

# The configuration file for scollector is dropped in the configuration path
# when the resource is provisioned because it contains environment specific information
scollector_config_path = node['scollector']['conf_dir']
scollector_config_file = "#{scollector_config_path}/scollector.toml"

directory scollector_config_path do
  action :create
end

#
# INSTALL SCOLLECTOR
#

scollector_install_path = node['scollector']['bin_path']
node.default['scollector']['arch'] = 'amd64'

binary = "scollector-#{node['os']}-#{node['scollector']['arch']}"
remote_file 'scollector' do
  path scollector_install_path
  source "#{node['scollector']['release_url']}/#{node['scollector']['version']}/#{binary}"
  owner 'root'
  mode '0755'
  action :create
end

# Create the systemd service for scollector. Set it to depend on the network being up
# so that it won't start unless the network stack is initialized and has an
# IP address
systemd_service 'scollector' do
  action :create
  after %w[network-online.target]
  description 'SCollector'
  documentation 'http://bosun.org/scollector/'
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    exec_start "#{scollector_install_path} -conf #{scollector_config_file}"
    restart 'on-failure'
  end
  requires %w[network-online.target]
end

service 'scollector' do
  action :enable
end

scollector_template_file = node['scollector']['consul_template_file']
file "#{consul_template_template_path}/#{scollector_template_file}" do
  action :create
  content <<~CONF
    Host = "http://{{ keyOrDefault "config/services/metrics/protocols/opentsdb/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "unknown" }}:{{ keyOrDefault "config/services/metrics/protocols/opentsdb/port" "80" }}"

    [Tags]
        environment = "{{ keyOrDefault "config/services/consul/datacenter" "unknown" }}"
        os = "linux"
  CONF
  mode '755'
end

# Create the consul-template configuration file
scollector_config_file = node['scollector']['config_file']
scollector_install_path = node['scollector']['conf_dir']
file "#{consul_template_config_path}/scollector.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{scollector_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{scollector_install_path}/#{scollector_config_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "systemctl restart scollector"

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
      perms = 0755

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
  mode '755'
end
