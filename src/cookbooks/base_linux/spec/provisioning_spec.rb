# frozen_string_literal: true

require 'spec_helper'

describe 'base_linux::provisioning' do
  context 'configures provisioning' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs the dos2unix package' do
      expect(chef_run).to install_apt_package('dos2unix')
    end

    it 'installs the pwgen package' do
      expect(chef_run).to install_apt_package('pwgen')
    end

    it 'installs the jq package' do
      expect(chef_run).to install_apt_package('jq')
    end

    it 'creates provision_helpers.sh in the /etc/provision.d directory' do
      expect(chef_run).to create_file('/etc/provision.d/provision_helpers.sh').with(
        group: 'root',
        owner: 'root',
        mode: '0750'
      )
    end

    it 'creates provision_network_interfaces.sh in the /etc/provision.d directory' do
      expect(chef_run).to create_file('/etc/provision.d/provision_network_interfaces.sh').with(
        group: 'root',
        owner: 'root',
        mode: '0750'
      )
    end

    it 'creates provision_consul.sh in the /etc/provision.d directory' do
      expect(chef_run).to create_file('/etc/provision.d/provision_consul.sh').with(
        group: 'root',
        owner: 'root',
        mode: '0750'
      )
    end

    it 'creates provision_consul-template.sh in the /etc/provision.d directory' do
      expect(chef_run).to create_file('/etc/provision.d/provision_consul-template.sh').with(
        group: 'root',
        owner: 'root',
        mode: '0750'
      )
    end

    it 'creates provision_unbound.sh in the /etc/provision.d directory' do
      expect(chef_run).to create_file('/etc/provision.d/provision_unbound.sh').with(
        group: 'root',
        owner: 'root',
        mode: '0750'
      )
    end

    it 'creates provision.sh in the /etc/provision.d directory' do
      expect(chef_run).to create_file('/etc/provision.d/provision.sh').with(
        group: 'root',
        owner: 'root',
        mode: '0750'
      )
    end

    it 'creates provision service in the /etc/systemd/system directory' do
      expect(chef_run).to create_file('/etc/systemd/system/provision.service')
    end

    it 'enables the provisioning service' do
      expect(chef_run).to enable_service('provision.service')
    end
  end
end
