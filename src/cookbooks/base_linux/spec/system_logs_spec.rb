# frozen_string_literal: true

require 'spec_helper'

describe 'base_linux::system_logs' do
  context 'configures syslog-ng' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs the syslog-ng-apt-repository apt_repository' do
      expect(chef_run).to add_apt_repository('syslog-ng-apt-repository').with(
        action: [:add],
        key: ['http://download.opensuse.org/repositories/home:/laszlo_budai:/syslog-ng/xUbuntu_18.04/Release.key'],
        uri: 'http://download.opensuse.org/repositories/home:/laszlo_budai:/syslog-ng/xUbuntu_18.04'
      )
    end

    it 'installs the syslog-ng-core package' do
      expect(chef_run).to install_apt_package('syslog-ng-core')
    end

    it 'installs the syslog-ng-mod-amqp package' do
      expect(chef_run).to install_apt_package('syslog-ng-mod-amqp')
    end

    it 'installs the syslog-ng-mod-json package' do
      expect(chef_run).to install_apt_package('syslog-ng-mod-json')
    end

    it 'creates the syslog config directory' do
      expect(chef_run).to create_directory('/etc/syslog-ng/conf.d')
    end

    syslog_template_content = <<~CONF
      @version: 3.18

      ########################
      # Destinations
      ########################
      # The RabbitMQ destination
      destination d_rabbit_syslog {
        amqp(
          body("$(format-json date=datetime($ISODATE) pid=$PID program=$PROGRAM message=$MESSAGE facility=$FACILITY host=$FULLHOST priorityNum=int64($LEVEL_NUM) priority=$LEVEL)")
          exchange("{{ keyOrDefault "config/services/queue/logs/syslog/exchange" "" }}")
          exchange-type("direct")
          host("{{ keyOrDefault "config/services/queue/protocols/amqp/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "consul" }}")
          port({{ keyOrDefault "config/services/queue/protocols/amqp/port" "80" }})
          routing-key("syslog")
          vhost("{{ keyOrDefault "config/services/queue/logs/syslog/vhost" "logs" }}")

      {{ with secret "secret/services/queue/users/logs/syslog" }}
        {{ if .Data.password }}
          password("{{ .Data.password }}")
          username("{{ .Data.username }}")
        {{ end }}
      {{ end }}
        );
      };

      ########################
      # Log paths
      ########################

      log { source(s_src); filter(f_syslog3); destination(d_rabbit_syslog); };
    CONF
    it 'creates syslog-ng template in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/syslog-ng.ctmpl')
        .with_content(syslog_template_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    consul_template_syslog_ng_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/syslog-ng.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/etc/syslog-ng/conf.d/syslog-ng-rabbitmq.conf"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "systemctl restart syslog-ng"

        # This is the maximum amount of time to wait for the optional command to
        # return. Default is 30s.
        command_timeout = "15s"

        # Exit with an error when accessing a struct or map field/key that does not
        # exist. The default behavior will print "<no value>" when accessing a field
        # that does not exist. It is highly recommended you set this to "true" when
        # retrieving secrets from Vault.
        error_on_missing_key = false

        # This is the permission to render the file. If this option is left
        # unspecified, Consul Template will attempt to match the permissions of the
        # file that already exists at the destination path. If no file exists at that
        # path, the permissions are 0644.
        perms = 0550

        # This option backs up the previously rendered template at the destination
        # path before writing a new one. It keeps exactly one backup. This option is
        # useful for preventing accidental changes to the data without having a
        # rollback strategy.
        backup = true

        # These are the delimiters to use in the template. The default is "{{" and
        # "}}", but for some templates, it may be easier to use a different delimiter
        # that does not conflict with the output file itself.
        left_delimiter  = "{{"
        right_delimiter = "}}"

        # This is the `minimum(:maximum)` to wait before rendering a new template to
        # disk and triggering a command, separated by a colon (`:`). If the optional
        # maximum value is omitted, it is assumed to be 4x the required minimum value.
        # This is a numeric time with a unit suffix ("5s"). There is no default value.
        # The wait value for a template takes precedence over any globally-configured
        # wait.
        wait {
          min = "2s"
          max = "10s"
        }
      }
    CONF
    it 'creates syslog-ng.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/syslog-ng.hcl')
        .with_content(consul_template_syslog_ng_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end
  end
end
