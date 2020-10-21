# frozen_string_literal: true

require 'spec_helper'

describe 'base_linux::envoy' do
  context 'configures envoy' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs the envoy-apt-repository apt_repository' do
      expect(chef_run).to add_apt_repository('envoy-apt-repository').with(
        action: [:add],
        key: ['https://getenvoy.io/gpg'],
        uri: 'https://dl.bintray.com/tetrate/getenvoy-deb'
      )
    end

    it 'installs the getenvoy-envoy package' do
      expect(chef_run).to install_apt_package('getenvoy-envoy')
    end
  end
end
