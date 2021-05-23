# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: os_packages
#
# Copyright 2021, P. van der Velde
#

#
# INSTALL GPG
#

# For some reason gpg doesn't exist, so we install it?
apt_package 'gpg-agent' do
  action :install
end
