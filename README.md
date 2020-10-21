# base.vm.linux

This repository contains the code used to build images containing the base operating system and tools
that are required by all Linux resources. Images can be created for Hyper-V or Azure.

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

* Read the files on the DVD drive (for Hyper-V) or from the `/run/cloud-init` directory (for Azure
  using [cloud-init](https://cloudinit.readthedocs.io/en/latest/)) and:
  * Disable SSH if the `allow_ssh.json` file does not exist
  * Copy the configuration files and certificates for consul, syslog-ng, telegraf and unbound
  * Enable all the deamons for the afore mentioned services
  * Execute the resource specific provisioning steps found in the `f_provisionImage` function in
    `/etc/init.d/provision_image.sh` file.
* Sets the host name to `cv<SHORT_NAME>-<MAJOR>-<MINOR>-<PATCH>-<16_CHARACTER_RANDOM_STRING>` where
  * `<SHORT_NAME>` - Is, in general, the name of the resource without the `Resource-` section
  * `<MAJOR>` - The major version number
  * `<MINOR>` - The minor version number
  * `<PATCH>` - The patch version number
  * `<16_CHARACTER_RANDOM_STRING>` - A cryptographically random string of 16 characters
* Eject the DVD if the provisioning files were obtained from DVD
* Restart the machine to ensure that all changes are locked in and so that the machine comes up
  with the new machine name

#### Consul config files

For Consul there are a number of configuration files that are expected in the provisioning location.
For server and client nodes they are:

* **consul/consul_region.json** - Contains the Consul datacenter and domain information
* **consul/consul_secrets.json** - Contains the [gossip encrypt](https://www.consul.io/docs/security/encryption#gossip-encryption) key
* [Optional] **consul/consul_connect.json** - Contains the configuration for Consul Connect
* [Optional] **consul/certs/consul_cert.key** - The key file for the certificate that Consul is going
  to use to encrypt node to node communication.
* [Optional] **consul/certs/consul_cert.crt** - The certificate file for the certificate that Consul
  is going to use to encrypt node to node communication
* [Optional] **consul/certs/consul_cert_bundle.crt** - The certificate bundle containing the root
  certificates for the node to node communication encryption

For client nodes also provide:

* **consul/client/consul_client_location.json** - Contains the configuration entries that tell Consul
  how to connect to the cluster

For server nodes specifically also provide:

* **consul/server/consul_server_bootstrap.json** - Contains the Consul bootstrap information
* **consul/server/consul_server_location.json** - Contains the configuration entries that tell Consul
  how to connect to the other cluster nodes

For examples on how to configure for Hyper-V please look at the configuration folder in the
[calvinverse.configuration](https://github.com/Calvinverse/calvinverse.configuration/tree/master/config/iso/shared/consul) repository. For examples on how to configure when using Azure review the `cloud-init`
files in the [infrastructure.azure.core.servicediscovery](https://github.com/Calvinverse/calvinverse.configuration/tree/master/config/iso/shared/consul) repository.

#### Unbound config files

For Unbound one configuration file is expected. This file is expected to be found in the provisioning location at: `unbound/unbound_zones.conf` and it is expected to contain the unbound zone information.

For examples on how to configure for Hyper-V please look at the configuration folder in the
[calvinverse.configuration](https://github.com/Calvinverse/calvinverse.configuration/tree/master/config/iso/shared/unbound) repository. For examples on how to configure when using Azure review the `cloud-init`
files in the [infrastructure.azure.core.servicediscovery](https://github.com/Calvinverse/calvinverse.configuration/tree/master/config/iso/shared/consul) repository.

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

### Hyper-V images

* In order to build a Hyper-V image the following properties need to be specified as part of the
  command line used to build the image:
  * `ShouldCreateHyperVImage` should be set to `true`
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

### Azure images

* In order to build an Azure image the following properties need to be specified as part of the
  command line used to build the image:
  * `ShouldCreateAzureImage` should be set to `true`
  * `AzureClientId` - The client ID of the [service principal](https://www.packer.io/docs/builders/azure/#authentication-for-azure)
  * `AzureClientCertPath` - The path to the [certificate](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest) for the service principal
  * `AzureLocation` - The name of the Azure region in which the image should be created
  * `AzureImageResourceGroup` - The name of the resource group into which the image should be stored
  * `AzureSubscriptionId` - The subscription ID


## Deploy

The base image should never be deployed to live running infrastructure hence it will not be needing deploy information.
