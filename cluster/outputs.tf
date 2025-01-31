output "resource-ids" {
  value = <<EOT
  
  Environment ID:   ${confluent_environment.main.id}
  Kafka Cluster ID: ${confluent_kafka_cluster.enterprise.id}
  Kafka topic name: {confluent_kafka_topic.orders.topic_name}

  Service Accounts and their Kafka API Keys (API Keys inherit the permissions granted to the owner):
  ${confluent_service_account.cluster_manager.display_name}:                     ${confluent_service_account.cluster_manager.id}
  ${confluent_service_account.cluster_manager.display_name}'s Kafka API Key:     "${confluent_api_key.cluster_manager_kafka_api_key.id}"
  ${confluent_service_account.cluster_manager.display_name}'s Kafka API Secret:  "${confluent_api_key.cluster_manager_kafka_api_key.secret}"
  
  EOT

  sensitive = true
}

output "app-tf-env" {
  value = <<EOT

  export KAFKA_REST_ENDPOINT="${confluent_kafka_cluster.enterprise.rest_endpoint}"
  export KAFKA_API_KEY="${confluent_api_key.cluster_manager_kafka_api_key.id}"
  export KAFKA_API_SECRET="${nonsensitive(confluent_api_key.cluster_manager_kafka_api_key.secret)}"  
  EOT
  sensitive = false
}

output "pla-dns-domain" {
  value = "${confluent_private_link_attachment.main.dns_domain}"
}