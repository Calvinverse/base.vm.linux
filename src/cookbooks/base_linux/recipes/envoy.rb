# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: envoy
#
# Copyright 2020, P. van der Velde
#

# It's currently not possible to install envoy. Waiting for:
# https://github.com/envoyproxy/envoy/issues/16867

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
    version '1.16.3.p0.gc4b7ab8-1p74.gbb8060d'
  end
end
