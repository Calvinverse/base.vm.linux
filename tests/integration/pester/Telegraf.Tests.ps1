Describe 'On the system' {
    Context 'system metrics' {
        It 'with binaries in /usr/local/bin' {
            '/usr/local/bin/telegraf' | Should Exist
        }

        It 'with default configuration in /etc/telegraf/telegraf.conf' {
            '/etc/telegraf/telegraf.conf' | Should Exist
        }

        $expectedContent = @'
Host = "http://opentsdb.metrics.service.integrationtest:4242"

[Tags]
    environment = "test-integration"
    os = "linux"

'@
        $scollectorConfigContent = Get-Content '/etc/telegraf/telegraf.conf' | Out-String
        It 'with the expected content in the configuration file' {
            $scollectorConfigContent | Should Be ($expectedContent -replace "`r", "")
        }
    }

    Context 'has been daemonized for system metrics' {
        $serviceConfigurationPath = '/etc/systemd/system/telegraf-system.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
                $false | Should Be $true
            }
        }

        $expectedContent = @'
[Unit]
Description=Telegraf - System
Requires=network-online.target
After=network-online.target
Documentation=https://docs.influxdata.com/telegraf

[Install]
WantedBy=multi-user.target

[Service]
ExecStart=telegraf --config /etc/telegraf/telegraf.conf --config-directory /etc/telegraf/telegraf.d/system
EnvironmentFile=/etc/environment
Restart=on-failure

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status telegraf-system
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'telegraf-system.service - Telegraf - System'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }

    Context 'has been daemonized for statsd metrics' {
        $serviceConfigurationPath = '/etc/systemd/system/telegraf-statsd.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
                $false | Should Be $true
            }
        }

        $expectedContent = @'
[Unit]
Description=Telegraf - Statsd
Requires=network-online.target
After=network-online.target
Documentation=https://docs.influxdata.com/telegraf

[Install]
WantedBy=multi-user.target

[Service]
ExecStart=telegraf --config /etc/telegraf/telegraf.conf --config-directory /etc/telegraf/telegraf.d/statsd
EnvironmentFile=/etc/environment
Restart=on-failure

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status telegraf-statsd
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'telegraf-statsd.service - Telegraf - Statsd'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }
}
