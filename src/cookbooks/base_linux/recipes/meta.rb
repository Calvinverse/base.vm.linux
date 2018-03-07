# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: meta
#
# Copyright 2017, P. van der Velde
#

resource_name = node['resource']['name']
ruby_block 'set_base_image_environment_information' do
  block do
    file = Chef::Util::FileEdit.new('/etc/environment')
    file.insert_line_if_no_match("BASE_IMAGE=#{resource_name}", "BASE_IMAGE=#{resource_name}")
    file.insert_line_if_no_match('STATSD_ENABLED_SERVICES=consul', 'STATSD_ENABLED_SERVICES=consul')
    file.write_file
  end
end
