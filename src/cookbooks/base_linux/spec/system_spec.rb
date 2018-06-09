# frozen_string_literal: true

require 'spec_helper'

describe 'base_linux::system' do
  context 'disables the apt-daily services' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'stops and disables the apt-daily.service' do
      expect(chef_run).to stop_systemd_unit('apt-daily.service')
      expect(chef_run).to disable_systemd_unit('apt-daily.service')
    end

    it 'stops and disables the apt-daily.timer' do
      expect(chef_run).to stop_systemd_unit('apt-daily.timer')
      expect(chef_run).to disable_systemd_unit('apt-daily.timer')
    end

    apt_periodic_content = <<~TXT
      APT::Periodic::Update-Package-Lists "0";
      APT::Periodic::Download-Upgradeable-Packages "0";
      APT::Periodic::AutocleanInterval "0";
    TXT
    it 'sets apt to never automatically update' do
      expect(chef_run).to create_file('/etc/apt/apt.conf.d/10periodic')
        .with_content(apt_periodic_content)
    end
  end
end
