# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: provisioning
#
# Copyright 2017, P. van der Velde
#

#
# INSTALL DOS2UNIX
#

apt_package 'dos2unix' do
  action :install
end

#
# INSTALL PWGEN
#

apt_package 'pwgen' do
  action :install
end

#
# CONFIGURE THE PROVISIONING SCRIPT
#

# Create the script containing the helper functions
file '/etc/init.d/provision_helpers.sh' do
  action :create
  content <<~BASH
    #!/bin/bash

    function f_getEth0Ip {
      local _ip _line
      while IFS=$': \t' read -a _line ;do
          [ -z "${_line%inet}" ] &&
            _ip=${_line[${#_line[1]}>4?1:2]} &&
            [ "${_ip#127.0.0.1}" ] && echo $_ip && return 0
        done< <(LANG=C /sbin/ifconfig eth0)
    }

    function setHostName {
      #Assign existing hostname to $hostn
      hostn=$(cat /etc/hostname)

      # Generate a 16 character password
      POSTFIX=$(pwgen --no-capitalize 16 1)

      NAME="cv${RESOURCE_SHORT_NAME}-${RESOURCE_VERSION_MAJOR}-${RESOURCE_VERSION_MINOR}-${RESOURCE_VERSION_PATCH}-${POSTFIX}"
      sudo sed -i "s/$hostn/$NAME/g" /etc/hosts
      sudo sed -i "s/$hostn/$NAME/g" /etc/hostname
    }
  BASH
  mode '755'
end

file '/etc/init.d/provision_consul.sh' do
  action :create
  content <<~BASH
    #!/bin/bash

    function f_provisionConsul {
      sudo systemctl stop consul.service
      sudo rm -rfv /var/lib/consul/*

      cp -a /mnt/dvd/consul/consul_region.json /etc/consul/conf.d/region.json
      dos2unix /etc/consul/conf.d/region.json

      cp -a /mnt/dvd/consul/consul_secrets.json /etc/consul/conf.d/secrets.json
      dos2unix /etc/consul/conf.d/secrets.json

      # Copy the consul client files if they exist
      if [ ! -f /mnt/dvd/consul/client/consul_client_location.json ]; then
        cp -a /mnt/dvd/consul/client/consul_client_location.json /etc/consul/conf.d/location.json
        dos2unix /etc/consul/conf.d/location.json
      fi

      # Copy the consul server files if they exist
      if [ ! -f /mnt/dvd/consul/server/consul_server_bootstrap.json ]; then
        cp -a /mnt/dvd/consul/server/consul_server_bootstrap.json /etc/consul/conf.d/bootstrap.json
        dos2unix /etc/consul/conf.d/bootstrap.json
      fi

      if [ ! -f /mnt/dvd/consul/server/consul_server_location.json ]; then
        cp -a /mnt/dvd/consul/server/consul_server_location.json /etc/consul/conf.d/location.json
        dos2unix /etc/consul/conf.d/location.json
      fi
    }
  BASH
  mode '755'
end

file '/etc/init.d/provision_consul-template.sh' do
  action :create
  content <<~BASH
    #!/bin/bash

    function f_provisionConsulTemplate {
      cp -a /mnt/dvd/consul-template/vault.hcl /etc/consul-template.d/conf/vault.hcl
      dos2unix /etc/consul-template.d/conf/vault.hcl

      sudo systemctl enable consul-template.service
    }
  BASH
  mode '755'
end

file '/etc/init.d/provision_unbound.sh' do
  action :create
  content <<~BASH
    #!/bin/bash

    function f_provisionUnbound {
      cp -a /mnt/dvd/unbound/unbound_zones.conf /etc/unbound.d/unbound_zones.conf
      dos2unix /etc/unbound.d/unbound_zones.conf

      sudo systemctl enable unbound.service
    }
  BASH
  mode '755'
end

# Create the provisioning script
file '/etc/init.d/provision.sh' do
  action :create
  content <<~BASH
    #!/bin/bash

    . /etc/init.d/provision_helpers.sh
    . /etc/init.d/provision_consul.sh
    . /etc/init.d/provision_consul-template.sh
    . /etc/init.d/provision_unbound.sh

    FLAG="/var/log/firstboot.log"
    if [ ! -f $FLAG ]; then
      #
      # MOUNT THE DVD WITH THE CONFIGURATION FILES
      #
      if [ ! -d /mnt/dvd ]; then
        mkdir /mnt/dvd
      fi
      mount /dev/dvd /mnt/dvd

      if [ ! -f /mnt/dvd/run_provisioning.json ]; then
        umount /dev/dvd
        echo 'run_provisioning.json not found on DVD. Will not execute provisioning'
        exit 0
      fi

      IPADDRESS=$(f_getEth0Ip)

      #
      # CREATE MACHINE SPECIFIC CONFIGURATION FILES
      #
      # Create '/etc/consul/conf.d/connections.json'
      # echo "{ \\"advertise_addr\\": \\"${IPADDRESS}\\", \\"bind_addr\\": \\"${IPADDRESS}\\" }"  > /etc/consul/conf.d/connections.json

      #
      # CONFIGURE SSH
      #
      # If the allow SSH file is not there, disable SSH in the firewall
      if [ ! -f /mnt/dvd/allow_ssh.json ]; then
        ufw deny 22
      fi

      #
      # CONSUL CONFIGURATION
      #
      # Stop the consul service and kill the data directory. It will have the consul node-id in it which must go!
      f_provisionConsul

      #
      # CONSUL-TEMPLATE CONFIGURATION
      #
      f_provisionConsulTemplate

      #
      # UNBOUND CONFIGURATION
      #
      f_provisionUnbound

      #
      # UNMOUNT DVD
      #
      umount /dev/dvd
      eject -T /dev/dvd

      # The next line creates an empty file so it won't run the next boot
      touch $FLAG

      # restart the machine so that all configuration settings take hold
      sudo shutdown -r now
    else
      echo "Provisioning script ran previously so nothing to do"
    fi
  BASH
  mode '755'
end

# Create the service that is going to run the script
file '/etc/systemd/system/provision.service' do
  action :create
  content <<~SYSTEMD
    [Unit]
    Description=Provision the environment
    Requires=network-online.target
    After=network-online.target

    [Service]
    Type=oneshot
    ExecStart=/etc/init.d/provision.sh
    RemainAfterExit=true
    EnvironmentFile=-/etc/environment

    [Install]
    WantedBy=network-online.target
  SYSTEMD
end

# Make sure the service starts on boot
service 'provision.service' do
  action [:enable]
end