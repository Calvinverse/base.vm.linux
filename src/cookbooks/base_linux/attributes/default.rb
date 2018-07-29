# frozen_string_literal: true

#
# CONSUL
#

default['consul']['version'] = '1.2.0'
default['consul']['config']['domain'] = 'consulverse'

# This is not a consul server node
default['consul']['config']['server'] = false

# For the time being don't verify incoming and outgoing TLS signatures
default['consul']['config']['verify_incoming'] = false
default['consul']['config']['verify_outgoing'] = false

# Bind the client address to the local host. The advertise and bind addresses
# will be set in a separate configuration file
default['consul']['config']['client_addr'] = '127.0.0.1'

# Set the HTTP listener to listen on both the localhost address and the public IP address
# so that we can send command to consul from the localhost but also from the outside
default['consul']['config']['addresses'] = {
  http: '0.0.0.0'
}

# Do not allow consul to use the host information for the node id
default['consul']['config']['disable_host_node_id'] = true

# Disable remote exec
default['consul']['config']['disable_remote_exec'] = true

# Disable the update check
default['consul']['config']['disable_update_check'] = true

# Set the DNS configuration
default['consul']['config']['dns_config'] = {
  allow_stale: true,
  max_stale: '87600h',
  node_ttl: '30s',
  service_ttl: {
    '*': '30s'
  }
}

# Never leave the cluster if we are terminated
default['consul']['config']['leave_on_terminate'] = false
default['consul']['config']['skip_leave_on_interrupt'] = true

# Send all logs to syslog
default['consul']['config']['log_level'] = 'INFO'
default['consul']['config']['enable_syslog'] = true

default['consul']['config']['owner'] = 'root'

#
# CONSULTEMPLATE
#

default['consul_template']['install_directory'] = '/usr/local/bin'
default['consul_template']['install_path'] = "#{node['consul_template']['install_directory']}/consul-template"
default['consul_template']['data_path'] = '/etc/consul-template.d/data'
default['consul_template']['config_path'] = '/etc/consul-template.d/conf'
default['consul_template']['template_path'] = '/etc/consul-template.d/templates'

#
# FIREWALL
#

# Allow communication on the loopback address (127.0.0.1 and ::1)
default['firewall']['allow_loopback'] = true

# Do not allow MOSH connections
default['firewall']['allow_mosh'] = false

# Do not allow WinRM (which wouldn't work on Linux anyway, but close the ports just to be sure)
default['firewall']['allow_winrm'] = false

# No communication via IPv6 at all
default['firewall']['ipv6_enabled'] = false

#
# SYSLOG-NG
#

default['syslog_ng']['config_file'] = 'syslog-ng-rabbitmq.conf'
default['syslog_ng']['consul_template_file'] = 'syslog-ng.ctmpl'
default['syslog_ng']['config_path'] = '/etc/syslog-ng/conf.d'

#
# TELEGRAF
#

# Note that this should match whatever the dpkg telegraf sets up the service with
default['telegraf']['service_user'] = 'telegraf'
default['telegraf']['service_group'] = 'telegraf'

default['telegraf']['version'] = '1.7.2-1'
default['telegraf']['shasums'] = '100ecadedf5625af6d5bad31a625ce0e5778baae84c0eb89b3085489365539d8'
default['telegraf']['download_urls'] = 'https://dl.influxdata.com/telegraf/releases'

default['telegraf']['consul_template_file'] = 'telegraf.ctmpl'
default['telegraf']['config_file_path'] = '/etc/telegraf/telegraf.conf'
default['telegraf']['config_directory'] = '/etc/telegraf/telegraf.d'

default['telegraf']['statsd']['port'] = 8125

#
# UNBOUND
#

default['unbound']['service_user'] = 'unbound'
default['unbound']['service_group'] = 'unbound'

default['paths']['unbound_config'] = '/etc/unbound.d'

default['file_name']['unbound_config_file'] = 'unbound.conf'
