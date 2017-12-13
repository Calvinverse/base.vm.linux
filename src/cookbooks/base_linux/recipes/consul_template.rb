# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: consul_template
#
# Copyright 2017, P. van der Velde
#

# Configure the service user under which consultemplate will be run
poise_service_user node['consul_template']['service_user'] do
  group node['consul_template']['service_group']
end

#
# INSTALL FABIO
#

consul_template_install_path = node['consul_template']['install_path']
cookbook_file consul_template_install_path do
  action :create
  group 'root'
  mode '0755'
  owner 'root'
  source 'consul-template'
end

#
# CONFIGURATION
#

consul_template_config_path = node['consul_template']['config_path']
directory consul_template_config_path do
  action :create
  group 'root'
  mode '0755'
  owner 'root'
  recursive true
end

file "#{consul_template_config_path}/base.hcl" do
  action :create
  content <<~CONF
    # This denotes the start of the configuration section for Consul. All values
    # contained in this section pertain to Consul.
    consul {
      # This block specifies the basic authentication information to pass with the
      # request. For more information on authentication, please see the Consul
      # documentation.
      auth {
        enabled  = true
        username = "test"
        password = "test"
      }

      # This is the address of the Consul agent. By default, this is
      # 127.0.0.1:8500, which is the default bind and port for a local Consul
      # agent. It is not recommended that you communicate directly with a Consul
      # server, and instead communicate with the local Consul agent. There are many
      # reasons for this, most importantly the Consul agent is able to multiplex
      # connections to the Consul server and reduce the number of open HTTP
      # connections. Additionally, it provides a "well-known" IP address for which
      # clients can connect.
      address = "127.0.0.1:8500"

      # This is the ACL token to use when connecting to Consul. If you did not
      # enable ACLs on your Consul cluster, you do not need to set this option.
      #
      # This option is also available via the environment variable CONSUL_TOKEN.
      #token = "abcd1234"

      # This controls the retry behavior when an error is returned from Consul.
      # Consul Template is highly fault tolerant, meaning it does not exit in the
      # face of failure. Instead, it uses exponential back-off and retry functions
      # to wait for the cluster to become available, as is customary in distributed
      # systems.
      retry {
        # This enabled retries. Retries are enabled by default, so this is
        # redundant.
        enabled = true

        # This specifies the number of attempts to make before giving up. Each
        # attempt adds the exponential backoff sleep time. Setting this to
        # zero will implement an unlimited number of retries.
        attempts = 12

        # This is the base amount of time to sleep between retry attempts. Each
        # retry sleeps for an exponent of 2 longer than this base. For 5 retries,
        # the sleep times would be: 250ms, 500ms, 1s, 2s, then 4s.
        backoff = "250ms"

        # This is the maximum amount of time to sleep between retry attempts.
        # When max_backoff is set to zero, there is no upper limit to the
        # exponential sleep between retry attempts.
        # If max_backoff is set to 10s and backoff is set to 1s, sleep times
        # would be: 1s, 2s, 4s, 8s, 10s, 10s, ...
        max_backoff = "1m"
      }

      # This block configures the SSL options for connecting to the Consul server.
      ssl {
        # This enables SSL. Specifying any option for SSL will also enable it.
        enabled = false

        # This enables SSL peer verification. The default value is "true", which
        # will check the global CA chain to make sure the given certificates are
        # valid. If you are using a self-signed certificate that you have not added
        # to the CA chain, you may want to disable SSL verification. However, please
        # understand this is a potential security vulnerability.
        # verify = false

        # This is the path to the certificate to use to authenticate. If just a
        # certificate is provided, it is assumed to contain both the certificate and
        # the key to convert to an X509 certificate. If both the certificate and
        # key are specified, Consul Template will automatically combine them into an
        # X509 certificate for you.
        # cert = "/path/to/client/cert"
        # key  = "/path/to/client/key"

        # This is the path to the certificate authority to use as a CA. This is
        # useful for self-signed certificates or for organizations using their own
        # internal certificate authority.
        # ca_cert = "/path/to/ca"

        # This is the path to a directory of PEM-encoded CA cert files. If both
        # `ca_cert` and `ca_path` is specified, `ca_cert` is preferred.
        # ca_path = "path/to/certs/"

        # This sets the SNI server name to use for validation.
        # server_name = "my-server.com"
      }
    }

    # This is the signal to listen for to trigger a reload event. The default
    # value is shown below. Setting this value to the empty string will cause CT
    # to not listen for any reload signals.
    reload_signal = "SIGHUP"

    # This is the signal to listen for to trigger a graceful stop. The default
    # value is shown below. Setting this value to the empty string will cause CT
    # to not listen for any graceful stop signals.
    kill_signal = "SIGINT"

    # This is the maximum interval to allow "stale" data. By default, only the
    # Consul leader will respond to queries; any requests to a follower will
    # forward to the leader. In large clusters with many requests, this is not as
    # scalable, so this option allows any follower to respond to a query, so long
    # as the last-replicated data is within these bounds. Higher values result in
    # less cluster load, but are more likely to have outdated data.
    max_stale = "10m"

    # This is the log level. If you find a bug in Consul Template, please enable
    # debug logs so we can help identify the issue. This is also available as a
    # command line flag.
    log_level = "info"

    # This is the path to store a PID file which will contain the process ID of the
    # Consul Template process. This is useful if you plan to send custom signals
    # to the process.
    pid_file = "/tmp/consul-template/pid"

    # This is the quiescence timers; it defines the minimum and maximum amount of
    # time to wait for the cluster to reach a consistent state before rendering a
    # template. This is useful to enable in systems that have a lot of flapping,
    # because it will reduce the the number of times a template is rendered.
    wait {
      min = "5s"
      max = "10s"
    }

    # This block defines the configuration for connecting to a syslog server for
    # logging.
    syslog {
      # This enables syslog logging. Specifying any other option also enables
      # syslog logging.
      enabled = true

      # This is the name of the syslog facility to log to.
      facility = "syslog"
    }

    # This block defines the configuration for de-duplication mode. Please see the
    # de-duplication mode documentation later in the README for more information
    # on how de-duplication mode operates.
    deduplicate {
      # This enables de-duplication mode. Specifying any other options also enables
      # de-duplication mode.
      enabled = true

      # This is the prefix to the path in Consul's KV store where de-duplication
      # templates will be pre-rendered and stored.
      prefix = "consul-template/dedup/"
    }
  CONF
end

directory '/tmp/consul-template' do
  action :create
end

consul_template_template_path = node['consul_template']['template_path']
directory consul_template_template_path do
  action :create
  group 'root'
  mode '0755'
  owner 'root'
end

#
# SERVICE
#

# Create the systemd service for consultemplate.
systemd_service 'consul-template' do
  action :create
  after %w[multi-user.target]
  description 'Consul Template'
  documentation 'https://github.com/hashicorp/consul-template'
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    exec_start "#{consul_template_install_path} -config=#{consul_template_config_path} -config=#{consul_template_template_path}"
    restart 'on-failure'
  end
  requires %w[multi-user.target]
end

# Make sure the consultemplate service doesn't start automatically. This will be changed
# after we have provisioned the box
service 'consul-template' do
  action :disable
end
