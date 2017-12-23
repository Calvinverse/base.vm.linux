function Set-ConsulKV
{
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


    # connect to the actual local consul instance
    & /opt/consul/1.0.1/consul join -http-addr=http://127.0.0.1:8550 http://127.0.0.1:8500
}
