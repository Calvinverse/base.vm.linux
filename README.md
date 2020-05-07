# base.linux

This repository contains the code used to build an Ubuntu Hyper-V VM hard disk containing the
base operating system and tools that are required by all Linux resources.

## Image

### Contents

The current process will install Ubuntu 18.04.3 Server, i.e. without UI, on  the disk and will then
configure the following tools and services:

* [Consul](https://consul.io) - Provides service discovery for the environment as well as a distributed
  key-value store.
* [Consul-Template](https://github.com/hashicorp/consul-template) - Renders template files based on
  information stored in the `Consul` key-value store and the [Vault](https://vaultproject.io) secret
  store.
* [Syslog-ng](https://syslog-ng.org/) - Captures logs send to the
  [syslog stream](https://en.wikipedia.org/wiki/Syslog) and stores them both locally and forwards
  them onto the [central log storage server](https://github.com/Calvinverse/resource.documents.storage).
* [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/) - Captures metrics for the
  resource and forwards them onto the [time series database](https://github.com/Calvinverse/resource.metrics.storage)
  for storage and processing.
* [Unbound](https://www.unbound.net/) - A local DNS resolver to allow resolving DNS requests via
  Consul for the environment specific requests and external DNS servers for all other requests.

### Configuration

* A single network interface is configured, `eth0`, with DHCP enabled.
* SSH is enabled on port 22.
* The firewall is enabled and blocks all ports except the ports that are explicitly opened.
* All available updates will be applied.
* A single administrator level user is added called `thebigkahuna`.
* A set of standard applications are installed as mentioned above.
* Configurations for `Consul` and `Unbound` should be provided via the provisioning
  CD when a new machine is created from the base image. All other services and applications should
  obtain their configuration via `Consul-Template` and the `Consul` key-value store.

### Provisioning

For provisoning reasons a [systemd](https://wiki.ubuntu.com/systemd) [daemon](https://en.wikipedia.org/wiki/Daemon_(computing))
called `provision` is added which:

* Read the files on the DVD drive and:
  * Disable SSH if the `allow_ssh.json` file does not exist
  * Copy the configuration files for consul, syslog-ng, telegraf and unbound
  * Enable all the deamons for the afore mentioned services
  * Execute the resource specific provisioning steps found in the `f_provisionImage` function in
    `/etc/init.d/provision_image.sh` file.
* Sets the host name to `cv<SHORT_NAME>-<MAJOR>-<MINOR>-<PATCH>-<16_CHARACTER_RANDOM_STRING>` where
  * `<SHORT_NAME>` - Is, in general, the name of the resource without the `Resource-` section
  * `<MAJOR>` - The major version number
  * `<MINOR>` - The minor version number
  * `<PATCH>` - The patch version number
  * `<16_CHARACTER_RANDOM_STRING>` - A cryptographically random string of 16 characters
* Eject the DVD
* Restart the machine to ensure that all changes are locked in and so that the machine comes up
  with the new machine name

### Logs

Logs are collected via the [Syslog-ng](https://syslog-ng.org/) which will normally write the logs to
disk. If the Consul-Template service has been provided with the appropriate credentials then it will
generate additional configuration for the syslog service that allows the logs to be pushed to a
RabbitMQ exchange. The exchange the log messages are pushed to is determined by the
Consul Key-Value key at `config/services/queue/logs/syslog/exchange` on the
[vhost](https://www.rabbitmq.com/vhosts.html) defined by the `config/services/queue/logs/syslog/vhost`
K-V key. The `syslog` routing key is applied to each log message.

### Metrics

Metrics are collected through different means.

* Metrics for Consul are collected by Consul sending [StatsD](https://www.consul.io/docs/agent/telemetry.html)
  metrics to [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/).
* Metrics for Unbound are collected by Telegraf pulling the metrics.
* System metrics, e.g. CPU, disk, network and memory usage, are collected by Telegraf.

## Build, test and release

The build process follows the standard procedure for
[building Calvinverse images](https://www.calvinverse.net/documentation/how-to-build). Because the base
image is build during this process the following differences exist.

* The Ubuntu Server 18.04.3 ISO is obtained from the internal storage as defined by the MsBuild
  property `IsoDirectory`.
* A number of additional scripts and configuration files have to be gathered. Amongst these files is
  the Ubuntu `preseed.cfg` file. The preseed file contains the OS configuration and it is provided
  to the machine when booting from the ISO initially.
* Once Packer has created the VM it will additionally
  * Add the OS ISO as a secondary DVD drive
  * Start the machine and provide the boot command which points the machine to the ISO and the location of the preseed
    file. The OS installation will start and during this process the preseed file is read leading the machine to be
    configured with
    * A US english culture
    * In the UTC timezone
    * A single administrator user called `thebigkahuna`
    * Four partitions on the hard drive for:
      * BIOS boot
      * EFI boot
      * OS boot (mounted as `/boot`)
      * Swap
      * General use (mounted as `/`)
    * The Hyper-V packages necessary for Hyper-V to connect to Linux
  * Once the OS is installed the standard process will be followed

## Deploy

The base image should never be deployed to live running infrastructure hence it will not be needing deploy information.
