# Confluent Cloud Enterprise Cluster with Private link connectivity (Azure)

The following terraform scripts are provided in this example:

- [Cluster](./cluster) - Creates a Confluent Cloud Enterprise cluster with PrivateLink connectivity
- [App](./app) - Creates resources for an application (example topic, consumer and producer service account with their respective api-key)
- [Peering](./peering) - Creates a second vNet in a different region and a VMs as setup for a hub-spoke playgroung and vNet transitivity testing
- [Proxy](./proxy) - Creates a VM with Nginx proxy on the Hub vNet to access the data plane of the cluster via Rest API, when using the UI of Confluent Cloud via your browser

The examples assume Azure as Cloud Provider.

The App example includes a simple Produce and Consume commands using [Confluent CLI](https://docs.confluent.io/confluent-cli/current/install.html)
Please **note** that these should work from the vNet where the PL was created

Peering can be confirmed by simple 'ping' between the VMs of the vNets

## General usage

Depending on the provider you would need to expose environment variables with the expected credentials, these are commented in each of the 'main.tf' files

## Peering

The `Cluster` scripts create not only the Private Link Attachment and Connection, but also a Hosted Private DNS zone to resolve the cluster on the connected network (HUB)

The `Peering` scripts create Spoke vNets and update the Private DNS by adding a network link to each peered vNet, to resolve the private IP's of the Enterprise cluster.
You must include the name of the dns as variables of the `Peering` cluster, which is provided in the output of the `Cluster` script `terraform output pla-dns-domain`.

## Proxy

The NGINX proxy create requires an IP that can be reached from the browsers machine. Public IP with firewall rules over HTTPs (443).
Additionally the browser must be able to resolve the cluster endpoint, one option is to add an entry on the `/etc/hosts` (for linux) or `c:\Windows\System32\Drivers\etc\hosts` (for windows).

```text
##
# Host Database
#
# localhost is used to configure the loopback interface
# when the system is booting.  Do not change this entry.
##
127.0.0.1       localhost
255.255.255.255 broadcasthost
::1             localhost
<Public IP Address of NGINX VM instance> <Kafka-REST-Endpoint>
```
