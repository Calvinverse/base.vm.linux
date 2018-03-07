# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: system
#
# Copyright 2017, P. van der Velde
#

#
# DISABLE THE UNATTEND UPDATE SERVICES
#
# Because they use apt which breaks the Packer build. These images are updated only once anyway. New updates
# will happen in a new image (see: https://github.com/boxcutter/ubuntu/issues/73#issuecomment-231679733)

systemd_unit 'apt-daily.service' do
  action %i[stop disable]
end

systemd_unit 'apt-daily.timer' do
  action %i[stop disable]
end
