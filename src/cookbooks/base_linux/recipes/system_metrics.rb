# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: system_metrics
#
# Copyright 2017, P. van der Velde
#

#
# INSTALL TELEGRAF
#

file_name = "telegraf_#{node['telegraf']['version']}_amd64.deb"
remote_file "#{Chef::Config[:file_cache_path]}/#{file_name}" do
  action :create
  checksum node['telegraf']['shasums']
  source "#{node['telegraf']['download_urls']}/#{file_name}"
end

dpkg_package 'telegraf' do
  action :install
  options '--force-confdef --force-confold'
  source "#{Chef::Config[:file_cache_path]}/#{file_name}"
end

telegraf_service = 'telegraf'
service telegraf_service do
  action :enable
end

# Set the permissions on the telegraf config directory so that telegraf can actually
# read from said directory
directory '/etc/telegraf' do
  action :create
  group node['telegraf']['service_user']
  mode '0550'
  owner node['telegraf']['service_group']
end

directory '/etc/telegraf/telegraf.d' do
  action :create
  group node['telegraf']['service_user']
  mode '0550'
  owner node['telegraf']['service_group']
end

#
# ALLOW TELEGRAF THROUGH THE FIREWALL
#

telegraf_statsd_port = node['telegraf']['statsd']['port']
firewall_rule 'telegraf-statsd' do
  command :allow
  description 'Allow Telegraf statsd traffic'
  dest_port telegraf_statsd_port
  direction :in
end

#
# DEFAULT CONFIGURATION
#

consul_template_template_path = node['consul_template']['template_path']
consul_template_config_path = node['consul_template']['config_path']

# The configuration file for telegraf is dropped in the configuration path
# when the resource is provisioned because it contains environment specific information
telegraf_template_file = node['telegraf']['consul_template_file']
file "#{consul_template_template_path}/#{telegraf_template_file}" do
  action :create
  content <<~CONF
    # Telegraf Configuration

    # Global tags can be specified here in key="value" format.
    [global_tags]
      environment = "{{ keyOrDefault "config/services/consul/datacenter" "unknown" }}"
      os = "linux"
      consul = "{{ env "CONSUL_SERVER_OR_CLIENT" | toLower }}"
      category = "{{ env "RESOURCE_SHORT_NAME" | toLower }}"

    # Configuration for telegraf agent
    [agent]
      ## Default data collection interval for all inputs
      interval = "10s"

      ## Rounds collection interval to 'interval'
      ## ie, if interval="10s" then always collect on :00, :10, :20, etc.
      round_interval = true

      ## Telegraf will send metrics to outputs in batches of at most
      ## metric_batch_size metrics.
      ## This controls the size of writes that Telegraf sends to output plugins.
      metric_batch_size = 1000

      ## For failed writes, telegraf will cache metric_buffer_limit metrics for each
      ## output, and will flush this buffer on a successful write. Oldest metrics
      ## are dropped first when this buffer fills.
      ## This buffer only fills when writes fail to output plugin(s).
      metric_buffer_limit = 10000

      ## Collection jitter is used to jitter the collection by a random amount.
      ## Each plugin will sleep for a random time within jitter before collecting.
      ## This can be used to avoid many plugins querying things like sysfs at the
      ## same time, which can have a measurable effect on the system.
      collection_jitter = "0s"

      ## Default flushing interval for all outputs. You shouldn't set this below
      ## interval. Maximum flush_interval will be flush_interval + flush_jitter
      flush_interval = "10s"
      ## Jitter the flush interval by a random amount. This is primarily to avoid
      ## large write spikes for users running a large number of telegraf instances.
      ## ie, a jitter of 5s and interval 10s means flushes will happen every 10-15s
      flush_jitter = "0s"

      ## By default or when set to "0s", precision will be set to the same
      ## timestamp order as the collection interval, with the maximum being 1s.
      ##   ie, when interval = "10s", precision will be "1s"
      ##       when interval = "250ms", precision will be "1ms"
      ## Precision will NOT be used for service inputs. It is up to each individual
      ## service input to set the timestamp at the appropriate precision.
      ## Valid time units are "ns", "us" (or "µs"), "ms", "s".
      precision = ""

      ## Logging configuration:
      ## Run telegraf with debug log messages.
      debug = false
      ## Run telegraf in quiet mode (error log messages only).
      quiet = false
      ## Specify the log file name. The empty string means to log to stderr.
      logfile = "/var/log/syslog"

      ## Override default hostname, if empty use os.Hostname()
      hostname = ""
      ## If set to true, do no set the "host" tag in the telegraf agent.
      omit_hostname = false

    ###############################################################################
    #                            INPUT PLUGINS                                    #
    ###############################################################################

    # Read metrics about cpu usage
    [[inputs.cpu]]
      ## Whether to report per-cpu stats or not
      percpu = true
      ## Whether to report total system cpu stats or not
      totalcpu = true
      ## If true, collect raw CPU time metrics.
      collect_cpu_time = false
      ## If true, compute and report the sum of all non-idle CPU states.
      report_active = false
      [inputs.cpu.tags]
        influxdb_database = "system"


    # Read metrics about disk usage by mount point
    [[inputs.disk]]
      ## By default, telegraf gather stats for all mountpoints.
      ## Setting mountpoints will restrict the stats to the specified mountpoints.
      # mount_points = ["/"]

      ## Ignore some mountpoints by filesystem type. For example (dev)tmpfs (usually
      ## present on /run, /var/run, /dev/shm or /dev).
      ignore_fs = ["tmpfs", "devtmpfs", "devfs"]
      [inputs.disk.tags]
        influxdb_database = "system"


    # Read metrics about disk IO by device
    [[inputs.diskio]]
      ## By default, telegraf will gather stats for all devices including
      ## disk partitions.
      ## Setting devices will restrict the stats to the specified devices.
      # devices = ["sda", "sdb"]
      ## Uncomment the following line if you need disk serial numbers.
      # skip_serial_number = false
      #
      ## On systems which support it, device metadata can be added in the form of
      ## tags.
      ## Currently only Linux is supported via udev properties. You can view
      ## available properties for a device by running:
      ## 'udevadm info -q property -n /dev/sda'
      # device_tags = ["ID_FS_TYPE", "ID_FS_USAGE"]
      #
      ## Using the same metadata source as device_tags, you can also customize the
      ## name of the device via templates.
      ## The 'name_templates' parameter is a list of templates to try and apply to
      ## the device. The template may contain variables in the form of '$PROPERTY' or
      ## '${PROPERTY}'. The first template which does not contain any variables not
      ## present for the device is used as the device name tag.
      ## The typical use case is for LVM volumes, to get the VG/LV name instead of
      ## the near-meaningless DM-0 name.
      # name_templates = ["$ID_FS_LABEL","$DM_VG_NAME/$DM_LV_NAME"]
      [inputs.diskio.tags]
        influxdb_database = "system"


    # Get kernel statistics from /proc/stat
    [[inputs.kernel]]
      # no configuration
      [inputs.kernel.tags]
        influxdb_database = "system"


    # Read metrics about memory usage
    [[inputs.mem]]
      # no configuration
      [inputs.mem.tags]
        influxdb_database = "system"

    # Gather metrics about network interfaces
    [[inputs.net]]
      ## By default, telegraf gathers stats from any up interface (excluding loopback)
      ## Setting interfaces will tell it to gather these explicit interfaces,
      ## regardless of status. When specifying an interface, glob-style
      ## patterns are also supported.
      ##
      # interfaces = ["eth*", "enp0s[0-1]", "lo"]
      ##
      [inputs.net.tags]
        influxdb_database = "system"


    # Get the number of processes and group them by status
    [[inputs.processes]]
      # no configuration
      [inputs.processes.tags]
        influxdb_database = "system"


    # Read metrics about swap memory usage
    [[inputs.swap]]
      # no configuration
      [inputs.swap.tags]
        influxdb_database = "system"


    # Read metrics about system load & uptime
    [[inputs.system]]
      # no configuration
      [inputs.system.tags]
        influxdb_database = "system"

    # # A plugin to collect stats from Unbound - a validating, recursive, and caching DNS resolver
    [[inputs.unbound]]
      ## If running as a restricted user you can prepend sudo for additional access:
      # use_sudo = false

      ## The default location of the unbound-control binary can be overridden with:
      # binary = "/usr/sbin/unbound-control"

      ## The default timeout of 1s can be overriden with:
      # timeout = "1s"

      ## Use the builtin fielddrop/fieldpass telegraf filters in order to keep/remove specific fields
      # fieldpass = ["total_*", "num_*","time_up", "mem_*"]
      [inputs.unbound.tags]
        influxdb_database = "system"

    # Statsd UDP/TCP Server
    [[inputs.statsd]]
      ## Protocol, must be "tcp", "udp", "udp4" or "udp6" (default=udp)
      # protocol = "udp"

      ## MaxTCPConnection - applicable when protocol is set to tcp (default=250)
      # max_tcp_connections = 250

      ## Address and port to host UDP listener on
      service_address = ":#{telegraf_statsd_port}"

      ## The following configuration options control when telegraf clears it's cache
      ## of previous values. If set to false, then telegraf will only clear it's
      ## cache when the daemon is restarted.
      ## Reset gauges every interval (default=true)
      delete_gauges = true
      ## Reset counters every interval (default=true)
      delete_counters = true
      ## Reset sets every interval (default=true)
      delete_sets = true
      ## Reset timings & histograms every interval (default=true)
      delete_timings = true

      ## Percentiles to calculate for timing & histogram stats
      percentiles = [90]

      ## separator to use between elements of a statsd metric
      metric_separator = "_"

      ## Parses tags in the datadog statsd format
      ## http://docs.datadoghq.com/guides/dogstatsd/
      parse_data_dog_tags = false

      ## Statsd data translation templates, more info can be read here:
      ## https://github.com/influxdata/telegraf/blob/master/docs/DATA_FORMATS_INPUT.md#graphite
      templates = [
    {{ range $service := (env "STATSD_ENABLED_SERVICES" | split ";") }}
      {{ if keyExists (printf "config/services/%s/metrics/statsd/rules" $service) }}
        {{ key (printf "config/services/%s/metrics/statsd/rules" $service) | indent 4 }}
      {{ end }}
    {{ end }}
      ]

      ## Number of UDP messages allowed to queue up, once filled,
      ## the statsd server will start dropping packets
      allowed_pending_messages = 10000

      ## Number of timing/histogram values to track per-measurement in the
      ## calculation of percentiles. Raising this limit increases the accuracy
      ## of percentiles but also increases the memory usage and cpu time.
      # percentile_limit = 1000
      [inputs.statsd.tags]
        influxdb_database = "statsd"

    ###############################################################################
    #                            OUTPUT PLUGINS                                   #
    ###############################################################################

    {{ if keyExists "config/services/metrics/protocols/http/host" }}
    # Configuration for influxdb server to send metrics to
    [[outputs.influxdb]]
      ## The full HTTP or UDP URL for your InfluxDB instance.
      ##
      ## Multiple urls can be specified as part of the same cluster,
      ## this means that only ONE of the urls will be written to each interval.
      # urls = ["udp://127.0.0.1:8089"] # UDP endpoint example
      urls = ["http://{{ keyOrDefault "config/services/metrics/protocols/http/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "unknown" }}:{{ keyOrDefault "config/services/metrics/protocols/http/port" "80" }}"]
      ## The target database for metrics (telegraf will create it if not exists).
      database = "{{ keyOrDefault "config/services/metrics/databases/system" "system" }}" # required

      ## Name of existing retention policy to write to.  Empty string writes to
      ## the default retention policy.
      retention_policy = ""
      ## Write consistency (clusters only), can be: "any", "one", "quorum", "all"
      write_consistency = "any"

      ## Write timeout (for the InfluxDB client), formatted as a string.
      ## If not provided, will default to 5s. 0s means no timeout (not recommended).
      timeout = "5s"
    {{ with secret "secret/services/metrics/users/system" }}
      {{ if .Data.password }}
      username = "{{ .Data.username }}"
      password = "{{ .Data.password }}"
      {{ else }}
      # username = "telegraf"
      # password = "metricsmetricsmetricsmetrics"
      {{ end }}
    {{ end }}
      ## Set the user agent for HTTP POSTs (can be useful for log differentiation)
      user_agent = "telegraf"
      ## Set UDP payload size, defaults to InfluxDB UDP Client default (512 bytes)
      # udp_payload = 512

      ## Optional SSL Config
      # ssl_ca = "/etc/telegraf/ca.pem"
      # ssl_cert = "/etc/telegraf/cert.pem"
      # ssl_key = "/etc/telegraf/key.pem"
      ## Use SSL but skip chain & host verification
      # insecure_skip_verify = false

      ## HTTP Proxy Config
      # http_proxy = "http://corporate.proxy:3128"

      ## Optional HTTP headers
      # http_headers = {"X-Special-Header" = "Special-Value"}

      ## Compress each HTTP request payload using GZIP.
      # content_encoding = "gzip"
      [outputs.influxdb.tagpass]
        influxdb_database = ["system"]

    # Configuration for influxdb server to send metrics to
    [[outputs.influxdb]]
      ## The full HTTP or UDP URL for your InfluxDB instance.
      ##
      ## Multiple urls can be specified as part of the same cluster,
      ## this means that only ONE of the urls will be written to each interval.
      # urls = ["udp://127.0.0.1:8089"] # UDP endpoint example
      urls = ["http://{{ keyOrDefault "config/services/metrics/protocols/http/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "unknown" }}:{{ keyOrDefault "config/services/metrics/protocols/http/port" "80" }}"]
      ## The target database for metrics (telegraf will create it if not exists).
      database = "{{ keyOrDefault "config/services/metrics/databases/statsd" "statsd" }}" # required

      ## Name of existing retention policy to write to.  Empty string writes to
      ## the default retention policy.
      retention_policy = ""
      ## Write consistency (clusters only), can be: "any", "one", "quorum", "all"
      write_consistency = "any"

      ## Write timeout (for the InfluxDB client), formatted as a string.
      ## If not provided, will default to 5s. 0s means no timeout (not recommended).
      timeout = "5s"
    {{ with secret "secret/services/metrics/users/statsd" }}
      {{ if .Data.password }}
      username = "{{ .Data.username }}"
      password = "{{ .Data.password }}"
      {{ else }}
      # username = "telegraf"
      # password = "metricsmetricsmetricsmetrics"
      {{ end }}
    {{ end }}
      ## Set the user agent for HTTP POSTs (can be useful for log differentiation)
      user_agent = "telegraf"
      ## Set UDP payload size, defaults to InfluxDB UDP Client default (512 bytes)
      # udp_payload = 512

      ## Optional SSL Config
      # ssl_ca = "/etc/telegraf/ca.pem"
      # ssl_cert = "/etc/telegraf/cert.pem"
      # ssl_key = "/etc/telegraf/key.pem"
      ## Use SSL but skip chain & host verification
      # insecure_skip_verify = false

      ## HTTP Proxy Config
      # http_proxy = "http://corporate.proxy:3128"

      ## Optional HTTP headers
      # http_headers = {"X-Special-Header" = "Special-Value"}

      ## Compress each HTTP request payload using GZIP.
      # content_encoding = "gzip"
      [outputs.influxdb.tagpass]
        influxdb_database = ["statsd"]

    # Configuration for influxdb server to send metrics to
    [[outputs.influxdb]]
      ## The full HTTP or UDP URL for your InfluxDB instance.
      ##
      ## Multiple urls can be specified as part of the same cluster,
      ## this means that only ONE of the urls will be written to each interval.
      # urls = ["udp://127.0.0.1:8089"] # UDP endpoint example
      urls = ["http://{{ keyOrDefault "config/services/metrics/protocols/http/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "unknown" }}:{{ keyOrDefault "config/services/metrics/protocols/http/port" "80" }}"]
      ## The target database for metrics (telegraf will create it if not exists).
      database = "{{ keyOrDefault "config/services/metrics/databases/services" "services" }}" # required

      ## Name of existing retention policy to write to.  Empty string writes to
      ## the default retention policy.
      retention_policy = ""
      ## Write consistency (clusters only), can be: "any", "one", "quorum", "all"
      write_consistency = "any"

      ## Write timeout (for the InfluxDB client), formatted as a string.
      ## If not provided, will default to 5s. 0s means no timeout (not recommended).
      timeout = "5s"
    {{ with secret "secret/services/metrics/users/services" }}
      {{ if .Data.password }}
      username = "{{ .Data.username }}"
      password = "{{ .Data.password }}"
      {{ else }}
      # username = "telegraf"
      # password = "metricsmetricsmetricsmetrics"
      {{ end }}
    {{ end }}
      ## Set the user agent for HTTP POSTs (can be useful for log differentiation)
      user_agent = "telegraf"
      ## Set UDP payload size, defaults to InfluxDB UDP Client default (512 bytes)
      # udp_payload = 512

      ## Optional SSL Config
      # ssl_ca = "/etc/telegraf/ca.pem"
      # ssl_cert = "/etc/telegraf/cert.pem"
      # ssl_key = "/etc/telegraf/key.pem"
      ## Use SSL but skip chain & host verification
      # insecure_skip_verify = false

      ## HTTP Proxy Config
      # http_proxy = "http://corporate.proxy:3128"

      ## Optional HTTP headers
      # http_headers = {"X-Special-Header" = "Special-Value"}

      ## Compress each HTTP request payload using GZIP.
      # content_encoding = "gzip"
      [outputs.influxdb.tagpass]
        influxdb_database = ["services"]
    {{ else }}
    # Send metrics to nowhere at all
    [[outputs.discard]]
      # no configuration
    {{ end }}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

# Create the consul-template configuration file
telegraf_config_file = node['telegraf']['config_file_path']
file "#{consul_template_config_path}/telegraf.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{telegraf_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{telegraf_config_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "/bin/bash -c '\\"chown #{node['telegraf']['service_user']}:#{node['telegraf']['service_group']} #{telegraf_config_file} && systemctl restart #{telegraf_service}\\"'"

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
