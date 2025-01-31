terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.15.0"
    }
  }
}

provider "azurerm" {
  features {
    # See. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#authenticating-to-azure
    #
    # Assuming a Service Principal with a Client Secret authentication, expose the following environment variables
    # use ARM_CLIENT_ID env var
    # use ARM_CLIENT_SECRET env var
    # use ARM_TENANT_ID env var
    # use ARM_SUBSCRIPTION_ID env var
  }
}

data "azurerm_resource_group" "hub_resource_group" {
  name = var.hub_resource_group_name
}

# Hub vNet (dfederico-vnet)
data "azurerm_virtual_network" "hub_vnet" {
  name                = var.hub_vnet_name
  resource_group_name = data.azurerm_resource_group.hub_resource_group.name
}

# Peered vNets
data "azurerm_virtual_network" "spoke_vnet1" {
  name                = var.spoke1_vnet_name
  resource_group_name = var.spoke1_resource_group_name
}

data "azurerm_virtual_network" "spoke_vnet2" {
  name                = var.spoke2_vnet_name
  resource_group_name = var.spoke2_resource_group_name
}

# DNS Private Resolver
resource "azurerm_private_dns_resolver" "dns_private_resolver" {
  name                = "${data.azurerm_virtual_network.hub_vnet.name}-dns-resolver"
  resource_group_name = data.azurerm_resource_group.hub_resource_group.name
  location            = data.azurerm_virtual_network.hub_vnet.location
  virtual_network_id  = data.azurerm_virtual_network.hub_vnet.id
}

resource "azurerm_subnet" "dns_subnet" {
  name                 = "outbounddns"
  virtual_network_name = data.azurerm_virtual_network.hub_vnet.name
  resource_group_name  = data.azurerm_virtual_network.hub_vnet.resource_group_name
  address_prefixes     = ["10.0.0.64/28"]

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}

# Outbound Endpoint
resource "azurerm_private_dns_resolver_outbound_endpoint" "outbound" {
  name                    = "outbound-endpoint"
  private_dns_resolver_id = azurerm_private_dns_resolver.dns_private_resolver.id
  location                = azurerm_private_dns_resolver.dns_private_resolver.location
  subnet_id               = azurerm_subnet.dns_subnet.id
}

# DNS Forwarding Ruleset
resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "dns_ruleset" {
  name                                       = "resolver-ruleset"
  resource_group_name                        = data.azurerm_resource_group.hub_resource_group.name
  location                                   = data.azurerm_resource_group.hub_resource_group.location
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.outbound.id]
}

# # Associate Ruleset with Peered vNets - THIS ONE FAILS BECAUSE 168.63.129.16 IP IS RESTRICTED
resource "azurerm_private_dns_resolver_forwarding_rule" "forward_rule" {
  name                      = "forward-to-azure-dns"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.dns_ruleset.id
  domain_name               = "westeurope.azure.private.confluent.cloud."
  enabled                   = true
  target_dns_servers {
    ip_address = "168.63.129.16"
    port       = 53
  }

  depends_on = [azurerm_private_dns_resolver_outbound_endpoint.outbound,
                azurerm_private_dns_resolver_dns_forwarding_ruleset.dns_ruleset]
}

# # Associate Ruleset with Peered vNets - THIS ONE FAILS BECAUSE IT IS IN A DIFFERENT REGION FROM THE PRIVATE DNS RESOLVER
# resource "azurerm_private_dns_resolver_virtual_network_link" "spoke1_vnet_link" {
#   name                      = "link-${var.spoke1_vnet_name}"
#   dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.dns_ruleset.id
#   virtual_network_id        = data.azurerm_virtual_network.spoke_vnet1.id
# }

resource "azurerm_private_dns_resolver_virtual_network_link" "spoke2_vnet_link" {
  name                      = "link-${var.spoke2_vnet_name}"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.dns_ruleset.id
  virtual_network_id        = data.azurerm_virtual_network.spoke_vnet2.id
}
