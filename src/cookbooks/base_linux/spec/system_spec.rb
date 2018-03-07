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
  end
end
