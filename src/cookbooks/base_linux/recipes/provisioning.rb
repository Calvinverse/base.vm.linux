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

provisioning_source_path = node['provision']['source_path']

# Create the script containing the helper functions
file "#{provision_config_path}/provision_helpers.sh" do
  action :create
  content <<~BASH
    #!/bin/bash

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
      cp -a #{provisioning_source_path}/consul/consul_region.json /tmp/region.json
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

      cp -a #{provisioning_source_path}/consul/consul_region.json /etc/consul/conf.d/region.json
      dos2unix /etc/consul/conf.d/region.json

      cp -a #{provisioning_source_path}/consul/consul_secrets.json /etc/consul/conf.d/secrets.json
      dos2unix /etc/consul/conf.d/secrets.json

      # Connect
      if [ -f #{provisioning_source_path}/consul/consul_connect.json ]; then
        cp -a #{provisioning_source_path}/consul/consul_connect.json /etc/consul/conf.d/connect.json
        dos2unix /etc/consul/conf.d/connect.json
      fi

      # TLS files
      if [ -f #{provisioning_source_path}/consul/certs/consul_cert.key ]; then
        cp -a #{provisioning_source_path}/consul/certs/consul_cert.key /etc/consul/conf.d/certs/cert.key
        dos2unix /etc/consul/conf.d/certs/cert.key
      fi

      if [ -f #{provisioning_source_path}/consul/certs/consul_cert.crt ]; then
        cp -a #{provisioning_source_path}/consul/certs/consul_cert.crt /etc/consul/conf.d/certs/cert.crt
        dos2unix /etc/consul/conf.d/certs/cert.crt
      fi

      if [ -f #{provisioning_source_path}/consul/certs/consul_cert_bundle.crt ]; then
        cp -a #{provisioning_source_path}/consul/certs/consul_cert_bundle.crt /etc/consul/conf.d/certs/bundle.crt
        dos2unix /etc/consul/conf.d/certs/bundle.crt
      fi

      # Copy the consul client files if they exist
      if [ -f #{provisioning_source_path}/consul/client/consul_client_location.json ]; then
        cp -a #{provisioning_source_path}/consul/client/consul_client_location.json /etc/consul/conf.d/location.json
        dos2unix /etc/consul/conf.d/location.json

        echo 'CONSUL_SERVER_OR_CLIENT=client' >> /etc/environment

        if [ -f #{provisioning_source_path}/consul/certs/consul_cert_bundle.crt ]; then
          cat <<JSON >> /etc/consul/conf.d/tls.json
    {
      "verify_incoming": false,
      "verify_outgoing": true,
      "verify_server_hostname": true,
      "ca_file": "/etc/consul/conf.d/certs/bundle.crt",
      "auto_encrypt": {
        "tls": true
      }
    }
    JSON
        fi
      fi

      # Copy the consul server files if they exist
      if [ -f #{provisioning_source_path}/consul/server/consul_server_bootstrap.json ]; then
        cp -a #{provisioning_source_path}/consul/server/consul_server_bootstrap.json /etc/consul/conf.d/bootstrap.json
        dos2unix /etc/consul/conf.d/bootstrap.json
      fi

      if [ -f #{provisioning_source_path}/consul/server/consul_server_location.json ]; then
        cp -a #{provisioning_source_path}/consul/server/consul_server_location.json /etc/consul/conf.d/location.json
        dos2unix /etc/consul/conf.d/location.json

        echo 'CONSUL_SERVER_OR_CLIENT=server' >> /etc/environment

        if [ -f #{provisioning_source_path}/consul/certs/consul_cert_bundle.crt ]; then
        cat <<JSON >> /etc/consul/conf.d/tls.json
    {
      "verify_incoming": true,
      "verify_outgoing": true,
      "verify_server_hostname": true,
      "key_file": "/etc/consul/conf.d/certs/cert.key",
      "cert_file": "/etc/consul/conf.d/certs/cert.crt",
      "ca_file": "/etc/consul/conf.d/certs/bundle.crt",
      "auto_encrypt": {
        "allow_tls": true
      }
    }
    JSON
        fi
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
      cp -a #{provisioning_source_path}/unbound/unbound_zones.conf /etc/unbound/unbound.conf.d/unbound_zones.conf
      dos2unix /etc/unbound/unbound.conf.d/unbound_zones.conf

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
      SHOULD_MOUNT_DVD='#{node['provision']['use_dvd']}'
      if [ "$SHOULD_MOUNT_DVD" == 'true' ]; then
        #
        # MOUNT THE DVD WITH THE CONFIGURATION FILES
        #
        if [ ! -d #{provisioning_source_path} ]; then
          mkdir #{provisioning_source_path}
        fi
        mount /dev/dvd #{provisioning_source_path}
      fi

      if [ ! -f #{provisioning_source_path}/run_provisioning.json ]; then
        umount /dev/dvd
        echo 'run_provisioning.json not found on DVD. Will not execute provisioning'
        exit 0
      fi

      #
      # CONFIGURE SSH
      #
      # If the allow SSH file is not there, disable SSH in the firewall
      if [ ! -f #{provisioning_source_path}/allow_ssh.json ]; then
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

      # Wait 30 seconds
      if [ -f #{provisioning_source_path}/run_provisioning.json ]; then
        DELAY=$(jq -r .delay_reboot #{provisioning_source_path}/run_provisioning.json)

        if [ -z "$DELAY" ]; then
          echo "No reboot delay"
        else
          echo "Waiting for reboot by $DELAY seconds ..."
          sleep $DELAY
        fi
      fi

      #
      # UNMOUNT DVD
      #
      if [ "$SHOULD_MOUNT_DVD" == 'true' ]; then
        umount /dev/dvd
      fi

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
    Requires=network.target
    After=network.target

    [Service]
    Type=oneshot
    ExecStart=#{provision_config_path}/provision.sh
    RemainAfterExit=true
    EnvironmentFile=-/etc/environment

    [Install]
    WantedBy=network.target
  SYSTEMD
end

# Make sure the service starts on boot
service 'provision.service' do
  action [:enable]
end
