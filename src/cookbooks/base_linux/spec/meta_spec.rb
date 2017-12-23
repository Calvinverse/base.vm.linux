# frozen_string_literal: true

require 'spec_helper'

describe 'base_linux::meta' do
  context 'updates the /etc/environment file' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'writes the product name to the environment variables' do
      expect(chef_run).to run_ruby_block('set_base_image_product_name')
    end
  end
end
