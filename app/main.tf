terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.12.0"
    }
  }
}

provider "confluent" {
# use KAFKA_REST_ENDPOINT env var
# use KAFKA_API_KEY env var
# use KAFKA_API_SECRET env var
}

data "confluent_environment" "main" {
  display_name = "AzureTest"
}

data "confluent_kafka_cluster" "enterprise" {
  display_name = "ECI_SERVERLESS"

  environment {
    id = data.confluent_environment.main.id
  }
}

resource "confluent_kafka_topic" "orders" {
  kafka_cluster {
    id = data.confluent_kafka_cluster.enterprise.id
  }
  topic_name    = "orders"
  rest_endpoint = data.confluent_kafka_cluster.enterprise.rest_endpoint
}

resource "confluent_service_account" "app-consumer" {
  display_name = "${data.confluent_kafka_cluster.enterprise.display_name}-app-consumer"
  description  = "dfederico - Service account to consume from '${confluent_kafka_topic.orders.topic_name}' topic of '${data.confluent_kafka_cluster.enterprise.display_name}' Kafka cluster"
}

resource "confluent_api_key" "app-consumer-kafka-api-key" {
  display_name = "${confluent_service_account.app-consumer.display_name}-api-key"
  description  = "dfederico - Kafka API Key that is owned by '${confluent_service_account.app-consumer.display_name}' service account"
  owner {
    id          = confluent_service_account.app-consumer.id
    api_version = confluent_service_account.app-consumer.api_version
    kind        = confluent_service_account.app-consumer.kind
  }

  managed_resource {
    id          = data.confluent_kafka_cluster.enterprise.id
    api_version = data.confluent_kafka_cluster.enterprise.api_version
    kind        = data.confluent_kafka_cluster.enterprise.kind

    environment {
      id = data.confluent_environment.main.id
    }
  }
}

resource "confluent_service_account" "app-producer" {
  display_name = "${data.confluent_kafka_cluster.enterprise.display_name}-app-producer"
  description  = "Service account to produce to '${confluent_kafka_topic.orders.topic_name}' topic of '${data.confluent_kafka_cluster.enterprise.display_name}' Kafka cluster"
}

resource "confluent_role_binding" "app-producer-developer-write" {
  principal   = "User:${confluent_service_account.app-producer.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${data.confluent_kafka_cluster.enterprise.rbac_crn}/kafka=${data.confluent_kafka_cluster.enterprise.id}/topic=${confluent_kafka_topic.orders.topic_name}"
}

resource "confluent_api_key" "app-producer-kafka-api-key" {
  display_name = "${confluent_service_account.app-producer.display_name}-api-key"
  description  = "dfederico Kafka API Key that is owned by '${confluent_service_account.app-producer.display_name}' service account"
  owner {
    id          = confluent_service_account.app-producer.id
    api_version = confluent_service_account.app-producer.api_version
    kind        = confluent_service_account.app-producer.kind
  }

  managed_resource {
    id          = data.confluent_kafka_cluster.enterprise.id
    api_version = data.confluent_kafka_cluster.enterprise.api_version
    kind        = data.confluent_kafka_cluster.enterprise.kind

    environment {
      id = data.confluent_environment.main.id
    }
  }
}

// Note that in order to consume from a topic, the principal of the consumer ('app-consumer' service account)
// needs to be authorized to perform 'READ' operation on both Topic and Group resources:
resource "confluent_role_binding" "app-consumer-developer-read-from-topic" {
  principal   = "User:${confluent_service_account.app-consumer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_kafka_cluster.enterprise.rbac_crn}/kafka=${data.confluent_kafka_cluster.enterprise.id}/topic=${confluent_kafka_topic.orders.topic_name}"
}

resource "confluent_role_binding" "app-consumer-developer-read-from-group" {
  principal = "User:${confluent_service_account.app-consumer.id}"
  role_name = "DeveloperRead"
  // The existing value of crn_pattern's suffix (group=confluent_cli_consumer_*) are set up to match Confluent CLI's default consumer group ID ("confluent_cli_consumer_<uuid>").
  // https://docs.confluent.io/confluent-cli/current/command-reference/kafka/topic/confluent_kafka_topic_consume.html
  // Update it to match your target consumer group ID.
  crn_pattern = "${data.confluent_kafka_cluster.enterprise.rbac_crn}/kafka=${data.confluent_kafka_cluster.enterprise.id}/group=confluent_cli_consumer_*"
}