# frozen_string_literal: true

require 'spec_helper'

describe 'base_linux::consul' do
  context 'configures consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }
    let(:node) { chef_run.node }

    it 'creates the consul config directory' do
      expect(chef_run).to create_directory('/etc/consul').with(
        group: 'consul',
        owner: 'consul',
        mode: '0750'
      )
    end

    it 'creates the consul additional config directory' do
      expect(chef_run).to create_directory('/etc/consul/conf.d').with(
        group: 'consul',
        owner: 'consul',
        mode: '0750'
      )
    end

    it 'imports the consul recipe' do
      expect(chef_run).to include_recipe('consul::default')
    end

    it 'updates the consul service definition' do
      expect(chef_run).to create_systemd_service('consul').with(
        action: [:create],
        service_exec_start: "/opt/consul/#{node['consul']['version']}/consul agent -config-file=/etc/consul/consul.json -config-dir=/etc/consul/conf.d",
        service_restart: 'always',
        service_restart_sec: 5,
        unit_after: %w[network.target],
        unit_description: 'consul',
        unit_wants: %w[network.target],
        unit_start_limit_interval_sec: 0
      )
    end
  end

  context 'creates the consul configuration files' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_metrics_content = <<~JSON
      {
          "telemetry": {
              "disable_hostname": true,
              "statsd_address": "127.0.0.1:8125"
          }
      }
    JSON
    it 'creates consul metrics configuration file in the consul configuration directory' do
      expect(chef_run).to create_file('/etc/consul/conf.d/metrics.json')
        .with_content(consul_metrics_content)
        .with(
          group: 'consul',
          owner: 'consul',
          mode: '0750'
        )
    end
  end

  context 'configures the firewall for consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Consul HTTP port' do
      expect(chef_run).to create_firewall_rule('consul-http').with(
        command: :allow,
        dest_port: 8500,
        direction: :in
      )
    end

    it 'opens the Consul DNS port' do
      expect(chef_run).to create_firewall_rule('consul-dns').with(
        command: :allow,
        dest_port: 8600,
        direction: :in,
        protocol: :udp
      )
    end

    it 'opens the Consul rpc port' do
      expect(chef_run).to create_firewall_rule('consul-rpc').with(
        command: :allow,
        dest_port: 8300,
        direction: :in
      )
    end

    it 'opens the Consul serf LAN TCP port' do
      expect(chef_run).to create_firewall_rule('consul-serf-lan-tcp').with(
        command: :allow,
        dest_port: 8301,
        direction: :in,
        protocol: :tcp
      )
    end

    it 'opens the Consul serf LAN UDP port' do
      expect(chef_run).to create_firewall_rule('consul-serf-lan-udp').with(
        command: :allow,
        dest_port: 8301,
        direction: :in,
        protocol: :udp
      )
    end

    it 'opens the Consul serf WAN TCP port' do
      expect(chef_run).to create_firewall_rule('consul-serf-wan-tcp').with(
        command: :allow,
        dest_port: 8302,
        direction: :in,
        protocol: :tcp
      )
    end

    it 'opens the Consul serf WAN UDP port' do
      expect(chef_run).to create_firewall_rule('consul-serf-wan-udp').with(
        command: :allow,
        dest_port: 8302,
        direction: :in,
        protocol: :udp
      )
    end
  end
end
