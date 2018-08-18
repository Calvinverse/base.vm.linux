# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: consul
#
# Copyright 2017, P. van der Velde
#

# Configure the service user under which consul will be run
poise_service_user node['consul']['service_user'] do
  group node['consul']['service_group']
end

#
# INSTALL CONSUL
#

consul_config_path = '/etc/consul'
consul_additional_config_path = '/etc/consul/conf.d'

# Set the permissions on the consul configuration paths so that consul can read and write
# It will later write the data folder to this location so it needs access
%W[#{consul_config_path} #{consul_additional_config_path}].each do |path|
  directory path do
    action :create
    group node['consul']['service_group']
    mode '0750'
    owner node['consul']['service_user']
    recursive true
  end
end

# This installs consul as follows
# - Binaries: /usr/local/bin/consul
# - Configuration: /etc/consul/consul.json and /etc/consul/conf.d
include_recipe 'consul::default'

#
# CONFIGURATION
#

telegraf_statsd_port = node['telegraf']['statsd']['port']
file '/etc/consul/conf.d/metrics.json' do
  action :create
  content <<~JSON
    {
        "telemetry": {
            "disable_hostname": true,
            "statsd_address": "127.0.0.1:#{telegraf_statsd_port}"
        }
    }
  JSON
  group node['consul']['service_group']
  mode '0750'
  owner node['consul']['service_user']
end

#
# ALLOW CONSUL THROUGH THE FIREWALL
#

firewall_rule 'consul-http' do
  command :allow
  description 'Allow Consul HTTP traffic'
  dest_port 8500
  direction :in
end

firewall_rule 'consul-dns' do
  command :allow
  description 'Allow Consul DNS traffic'
  dest_port 8600
  direction :in
  protocol :udp
end

firewall_rule 'consul-rpc' do
  command :allow
  description 'Allow Consul rpc LAN traffic'
  dest_port 8300
  direction :in
end

firewall_rule 'consul-serf-lan-tcp' do
  command :allow
  description 'Allow Consul serf LAN traffic on the TCP port'
  dest_port 8301
  direction :in
  protocol :tcp
end

firewall_rule 'consul-serf-lan-udp' do
  command :allow
  description 'Allow Consul serf LAN traffic on the UDP port'
  dest_port 8301
  direction :in
  protocol :udp
end

firewall_rule 'consul-serf-wan-tcp' do
  command :allow
  description 'Allow Consul serf WAN traffic on the TCP port'
  dest_port 8302
  direction :in
  protocol :tcp
end

firewall_rule 'consul-serf-wan-udp' do
  command :allow
  description 'Allow Consul serf WAN traffic on the UDP port'
  dest_port 8302
  direction :in
  protocol :udp
end
