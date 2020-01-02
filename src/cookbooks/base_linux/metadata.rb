# frozen_string_literal: true

chef_version '>= 12.5' if respond_to?(:chef_version)
description 'Environment cookbook that configures a base Linux server with all the shared tools and applications.'
issues_url '${ProductUrl}/issues' if respond_to?(:issues_url)
license 'Apache-2.0'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
name 'base_linux'
maintainer '${CompanyName} (${CompanyUrl})'
maintainer_email '${EmailDocumentation}'
source_url '${ProductUrl}' if respond_to?(:source_url)
version '${VersionSemantic}'

supports 'ubuntu', '>= 18.04'

depends 'apparmor', '= 3.1.0'
depends 'consul', '= 3.1.0'
depends 'firewall', '= 2.7.0'
depends 'systemd', '= 3.2.4'
depends 'trusted_certificate', '= 3.2.0'
