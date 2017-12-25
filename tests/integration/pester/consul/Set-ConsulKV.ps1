function Get-IpAddress
{
    $output = & /sbin/ifconfig eth0
    $line = $output |
        Where-Object { $_.Contains('inet addr:') } |
        Select-Object -First 1

    $line = $line.Trim()
    $line = $line.SubString('inet addr:'.Length)
    return $line.SubString(0, $line.IndexOf(' '))
}

function Set-ConsulKV
{
    Write-Output "Starting consul ..."
    $process = Start-Process -FilePath '/opt/consul/1.0.1/consul' -ArgumentList "agent -config-file /test/pester/consul/server.json" -PassThru -RedirectStandardOutput /test/pester/consul/consuloutput.out -RedirectStandardError /test/pester/consul/consulerror.out

    Write-Output "Going to sleep for 10 seconds ..."
    Start-Sleep -Seconds 10

    Write-Output "Setting consul key-values ..."

    # Load config/services/consul
    & /opt/consul/1.0.1/consul kv put -http-addr=http://127.0.0.1:8550 config/services/consul/datacenter 'test-integration'
    & /opt/consul/1.0.1/consul kv put -http-addr=http://127.0.0.1:8550 config/services/consul/domain 'integrationtest'

    # load config/services/queue
    & /opt/consul/1.0.1/consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/host 'active.queue'
    & /opt/consul/1.0.1/consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/port '5672'

    & /opt/consul/1.0.1/consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/logs/syslog/username 'testuser'
    & /opt/consul/1.0.1/consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/logs/syslog/vhost 'testlogs'

    # load config/services/metrics
    & /opt/consul/1.0.1/consul kv put -http-addr=http://127.0.0.1:8550 config/services/metrics/host 'write.metrics'
    & /opt/consul/1.0.1/consul kv put -http-addr=http://127.0.0.1:8550 config/services/metrics/port '4242'

    Write-Output "Joining the local consul ..."

    # connect to the actual local consul instance
    $ipAddress = Get-IpAddress
    Write-Output "Joining: $($ipAddress):8351"

    Start-Process -FilePath '/opt/consul/1.0.1/consul' -ArgumentList "join $($ipAddress):8351"

    Write-Output "Getting members for client"
    & /opt/consul/1.0.1/consul members

    Write-Output "Getting members for server"
    & /opt/consul/1.0.1/consul members -http-addr=http://127.0.0.1:8550

    Write-Output "Giving consul-template 30 seconds to process the data ..."
    Start-Sleep -Seconds 30
}
