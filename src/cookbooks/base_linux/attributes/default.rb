# frozen_string_literal: true

#
# CONSUL
#

default['consul']['version'] = '1.0.2'
default['consul']['config']['domain'] = 'consulverse'

# This is not a consul server node
default['consul']['config']['server'] = false

# For the time being don't verify incoming and outgoing TLS signatures
default['consul']['config']['verify_incoming'] = false
default['consul']['config']['verify_outgoing'] = false

# Bind the client address to the local host. The advertise and bind addresses
# will be set in a separate configuration file
default['consul']['config']['client_addr'] = '127.0.0.1'

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
  node_ttl: '10s',
  service_ttl: {
    '*': '10s'
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

default['consul_template']['install_path'] = '/usr/local/bin/consul-template'
default['consul_template']['data_path'] = '/etc/consul-template.d/data'
default['consul_template']['config_path'] = '/etc/consul-template.d/conf'
default['consul_template']['template_path'] = '/etc/consul-template.d/templates'

default['consul_template']['service_user'] = 'consul_template'
default['consul_template']['service_group'] = 'consul_template'

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

default['telegraf']['version'] = '1.5.2-1'
default['telegraf']['shasums'] = '8bc54e7005c1e4ff7d68a7cd724b65cddb9d8e09ad81c89e01f6819254f97a86'
default['telegraf']['download_urls'] = 'https://dl.influxdata.com/telegraf/releases'

default['telegraf']['config_file_path'] = '/etc/telegraf/telegraf.conf'

default['telegraf']['system']['service'] = 'telegraf-system'
default['telegraf']['system']['config_directory_path'] = '/etc/telegraf/telegraf.d/system'
default['telegraf']['system']['inputs_file'] = 'inputs.conf'
default['telegraf']['system']['consul_template_output_file'] = 'telegraf_system_outputs.ctmpl'

default['telegraf']['statsd']['service'] = 'telegraf-statsd'
default['telegraf']['statsd']['config_directory_path'] = '/etc/telegraf/telegraf.d/statsd'
default['telegraf']['statsd']['consul_template_input_file'] = 'telegraf_statsd_inputs.ctmpl'
default['telegraf']['statsd']['consul_template_output_file'] = 'telegraf_statsd_outputs.ctmpl'

#
# UNBOUND
#

default['unbound']['service_user'] = 'unbound'
default['unbound']['service_group'] = 'unbound'

default['paths']['unbound_config'] = '/etc/unbound.d'

default['file_name']['unbound_config_file'] = 'unbound.conf'
