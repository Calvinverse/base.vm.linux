# frozen_string_literal: true

require 'spec_helper'

describe 'base_linux::authentication_ssh' do
  before do
    stub_command("test $(awk '$5 < 2047 && $5 ~ /^[0-9]+$/ { print $5 }' /etc/ssh/moduli | uniq | wc -c) -eq 0").and_return(true)
  end

  context 'configures the user certificate' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_template_ssh_user_certificate_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This option allows embedding the contents of a template in the configuration
        # file rather then supplying the `source` path to the template file. This is
        # useful for short templates. This option is mutually exclusive with the
        # `source` option.
        contents = "{{ key \\"auth/ssh/client/ca/public\\" }}"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/etc/ssh/trusted-client-ca-keys.pem"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "/bin/bash -c 'echo \\"TrustedUserCAKeys /etc/ssh/trusted-client-ca-keys.pem\\" >> /etc/ssh/sshd_config && systemctl restart ssh'"

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
    it 'creates ssh_client.hcl in the consul-template configuration directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/ssh_client.hcl')
        .with_content(consul_template_ssh_user_certificate_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end
  end

  context 'configures the host certificate' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    ssh_host_key = '/etc/ssh/ssh_host_rsa_key.pub'

    consul_template_ssh_host_certificate_template_content = <<~CONF
      {{ with secret "ssh-host/sign/ROLE_HERE" "cert_type=host" "public_key=@"#{ssh_host_key} }}{{ .Data.signed_key }}{{ end }}
    CONF
    it 'creates ssh-host-certificate.ctmpl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/ssh-host-certificate.ctmpl')
        .with_content(consul_template_ssh_host_certificate_template_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    consul_template_ssh_host_certificate_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/ssh-host-certificate.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/etc/ssh/ssh_host_rsa_key-cert.pub"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "/bin/bash -c 'echo \\"HostKey #{ssh_host_key}\\" >> /etc/ssh/sshd_config && echo \\"HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub\\" >> /etc/ssh/sshd_config && systemctl restart ssh'"

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
        perms = 0640

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
    it 'creates ssh_host.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/ssh_host.hcl')
        .with_content(consul_template_ssh_host_certificate_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end
  end
end
