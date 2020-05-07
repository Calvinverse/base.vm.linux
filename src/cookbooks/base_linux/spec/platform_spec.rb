# frozen_string_literal: true

require 'spec_helper'

describe 'base_linux::default' do
  before do
    stub_command("test $(awk '$5 < 2047 && $5 ~ /^[0-9]+$/ { print $5 }' /etc/ssh/moduli | uniq | wc -c) -eq 0").and_return(true)
  end

  context 'configures the operating system' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'has the correct platform_version' do
      expect(chef_run.node['platform_version']).to eq('18.04')
    end
  end
end
