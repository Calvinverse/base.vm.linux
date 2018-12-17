# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: provisioning
#
# Copyright 2017, P. van der Velde
#

#
# INSTALL PACKAGES
#

%w[dos2unix pwgen jq].each do |pkg|
  apt_package pkg do
    action :install
  end
end

#
# DIRECTORIES
#
provision_config_path = node['provision']['config_path']
directory provision_config_path do
  action :create
end

#
# CONFIGURE THE PROVISIONING SCRIPT
#

# Create the script containing the helper functions
file "#{provision_config_path}/provision_helpers.sh" do
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

    function f_setHostName {
      # Generate a 16 character password
      POSTFIX=$(pwgen --no-capitalize 16 1)

      NAME="cv-${RESOURCE_SHORT_NAME}-${RESOURCE_VERSION_MAJOR}-${RESOURCE_VERSION_MINOR}-${RESOURCE_VERSION_PATCH}-${POSTFIX}"
      sudo sed -i "s/.*127.0.1.1.*/127.0.1.1\t${NAME}/g" /etc/hosts
      sudo hostnamectl set-hostname $NAME
    }
  BASH
  group 'root'
  mode '0750'
  owner 'root'
end

file "#{provision_config_path}/provision_network_interfaces.sh" do
  action :create
  content <<~BASH
    #!/bin/bash

    function f_provisionNetworkInterfaces {
      cp -a /mnt/dvd/consul/consul_region.json /tmp/region.json
      dos2unix /tmp/region.json
      DOMAIN=$(jq -r .domain /tmp/region.json)
      rm -rf /tmp/region.json

      cat <<EOT > /etc/network/interfaces
    # This file describes the network interfaces available on your system
    # and how to activate them. For more information, see interfaces(5).

    source /etc/network/interfaces.d/*

    # The loopback network interface
    auto lo
    iface lo inet loopback

    # The primary network interface
    auto eth0
    iface eth0 inet dhcp
        dns-search node.${DOMAIN}
        pre-up sleep 2
    EOT
    }
  BASH
  group 'root'
  mode '0750'
  owner 'root'
end

file "#{provision_config_path}/provision_consul.sh" do
  action :create
  content <<~BASH
    #!/bin/bash

    function f_provisionConsul {
      # Stop the consul service and kill the data directory. It will have the consul node-id in it which must go!
      sudo systemctl stop consul.service
      sudo rm -rfv /var/lib/consul/*

      cp -a /mnt/dvd/consul/consul_region.json /etc/consul/conf.d/region.json
      dos2unix /etc/consul/conf.d/region.json

      cp -a /mnt/dvd/consul/consul_secrets.json /etc/consul/conf.d/secrets.json
      dos2unix /etc/consul/conf.d/secrets.json

      # Copy the consul client files if they exist
      if [ -f /mnt/dvd/consul/client/consul_client_location.json ]; then
        cp -a /mnt/dvd/consul/client/consul_client_location.json /etc/consul/conf.d/location.json
        dos2unix /etc/consul/conf.d/location.json

        echo 'CONSUL_SERVER_OR_CLIENT=client' >> /etc/environment
      fi

      # Copy the consul server files if they exist
      if [ -f /mnt/dvd/consul/server/consul_server_bootstrap.json ]; then
        cp -a /mnt/dvd/consul/server/consul_server_bootstrap.json /etc/consul/conf.d/bootstrap.json
        dos2unix /etc/consul/conf.d/bootstrap.json
      fi

      if [ -f /mnt/dvd/consul/server/consul_server_location.json ]; then
        cp -a /mnt/dvd/consul/server/consul_server_location.json /etc/consul/conf.d/location.json
        dos2unix /etc/consul/conf.d/location.json

        echo 'CONSUL_SERVER_OR_CLIENT=server' >> /etc/environment
      fi
    }
  BASH
  group 'root'
  mode '0750'
  owner 'root'
end

file "#{provision_config_path}/provision_consul-template.sh" do
  action :create
  content <<~BASH
    #!/bin/bash

    function f_provisionConsulTemplate {
      sudo systemctl enable consul-template.service
    }
  BASH
  group 'root'
  mode '0750'
  owner 'root'
end

file "#{provision_config_path}/provision_unbound.sh" do
  action :create
  content <<~BASH
    #!/bin/bash

    function f_provisionUnbound {
      cp -a /mnt/dvd/unbound/unbound_zones.conf /etc/unbound.d/unbound_zones.conf
      dos2unix /etc/unbound.d/unbound_zones.conf

      sudo systemctl restart unbound.service
    }
  BASH
  group 'root'
  mode '0750'
  owner 'root'
end

# Create the provisioning script
file "#{provision_config_path}/provision.sh" do
  action :create
  content <<~BASH
    #!/bin/bash

    . #{provision_config_path}/provision_helpers.sh
    . #{provision_config_path}/provision_network_interfaces.sh
    . #{provision_config_path}/provision_consul.sh
    . #{provision_config_path}/provision_consul-template.sh
    . #{provision_config_path}/provision_unbound.sh

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

      #
      # CONFIGURE SSH
      #
      # If the allow SSH file is not there, disable SSH in the firewall
      if [ ! -f /mnt/dvd/allow_ssh.json ]; then
        ufw deny 22
      fi

      #
      # NETWORK INTERFACE CONFIGURATION
      #
      f_provisionNetworkInterfaces

      #
      # CONSUL CONFIGURATION
      #
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
      # CUSTOM PROVISIONING
      #
      if [ -f #{provision_config_path}/provision_image.sh ]; then
        . #{provision_config_path}/provision_image.sh
        f_provisionImage
      fi

      #
      # SET HOST NAME
      #
      f_setHostName

      #
      # UNMOUNT DVD
      #
      umount /dev/dvd
      eject -T /dev/dvd

      # The next line creates an empty file so it won't run the next boot
      touch $FLAG

      # restart the machine so that all configuration settings take hold (specifically the change in machine name)
      sudo shutdown -r now
    else
      echo "Provisioning script ran previously so nothing to do"
    fi
  BASH
  group 'root'
  mode '0750'
  owner 'root'
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
    ExecStart=#{provision_config_path}/provision.sh
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
