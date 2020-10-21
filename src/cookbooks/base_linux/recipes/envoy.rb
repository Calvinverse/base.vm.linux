# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: envoy
#
# Copyright 2020, P. van der Velde
#

apt_repository 'envoy-apt-repository' do
  action :add
  components %w[stable]
  key 'https://getenvoy.io/gpg'
  uri 'https://dl.bintray.com/tetrate/getenvoy-deb'
end

# Installing the syslog-ng package automatically creates a systemd daemon and replaces the other
# syslog daemons
%w[getenvoy-envoy].each do |pkg|
  apt_package pkg do
    action :install
    version '1.14.2.p0.g1a0363c-1p66.gfbeeb15'
  end
end
