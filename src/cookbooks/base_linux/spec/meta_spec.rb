# frozen_string_literal: true

require 'spec_helper'

describe 'base_linux::meta' do
  context 'updates the /etc/environment file' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'writes to the environment variables' do
      expect(chef_run).to run_ruby_block('set_base_image_environment_information')
    end
  end
end
