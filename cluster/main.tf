terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.12.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.15.0"
    }
  }
}


provider "confluent" {
# use CONFLUENT_CLOUD_API_KEY env var
# use CONFLUENT_CLOUD_API_SECRET env var
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

resource "confluent_environment" "main" {
  display_name = "AzureTest"
}

resource "confluent_network" "privatelink" {
  display_name     = "${confluent_environment.main.display_name} Private Link Network"
  cloud            = "AZURE"
  region           = var.region
  connection_types = ["PRIVATELINK"]
  environment {
    id = confluent_environment.main.id
  }

  dns_config {
    resolution = "PRIVATE"
  }
}

resource "confluent_private_link_access" "main" {
  display_name = "${confluent_environment.main.display_name} Azure Private Link Access"
  azure {
    subscription = var.azure_subscription_id
  }
  environment {
    id = confluent_environment.main.id
  }
  network {
    id = confluent_network.privatelink.id
  }
}

resource "confluent_kafka_cluster" "cluster" {
  display_name = "ECI_DEDICATED"
  availability = "MULTI_ZONE"
  cloud        = confluent_network.privatelink.cloud
  region       = var.region
  dedicated {
    cku = 2
  }
  environment {
    id = confluent_environment.main.id
  }
    network {
    id = confluent_network.privatelink.id
  }
}

module "privatelink" {
  source                        = "./azure-privatelink"
  resource_group                = var.resource_group
  vnet_region                   = var.region
  vnet_name                     = var.vnet_name
  dns_domain                    = confluent_network.privatelink.dns_domain
  private_link_service_aliases  = confluent_network.privatelink.azure[0].private_link_service_aliases
  subnet_name_by_zone           = var.subnet_name_by_zone
}

resource "confluent_service_account" "cluster_manager" {
  display_name = "cluster-manager"
  description  = "dfederico - Service account to manage ${confluent_kafka_cluster.cluster.display_name} Kafka cluster"
}

resource "confluent_role_binding" "cluster_manager_kafka_cluster_admin" {
  principal   = "User:${confluent_service_account.cluster_manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.cluster.rbac_crn
}

resource "confluent_api_key" "cluster_manager_kafka_api_key" {
  display_name = "${confluent_service_account.cluster_manager.display_name}-api-key"
  description  = "dfederico - Kafka API Key that is owned by '${confluent_service_account.cluster_manager.display_name}' service account"
  owner {
    id          = confluent_service_account.cluster_manager.id
    api_version = confluent_service_account.cluster_manager.api_version
    kind        = confluent_service_account.cluster_manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.cluster.id
    api_version = confluent_kafka_cluster.cluster.api_version
    kind        = confluent_kafka_cluster.cluster.kind

    environment {
      id = confluent_environment.main.id
    }
  }

  depends_on = [
    confluent_role_binding.cluster_manager_kafka_cluster_admin,
    module.privatelink,
    confluent_network.privatelink
  ]
}