output "container_name" {
  description = "Nom du conteneur déployé"
  value       = docker_container.web.name
}

output "network_name" {
  description = "Nom du réseau Docker"
  value       = docker_network.app_network.name
}

output "website_url" {
  description = "URL du serveur Web local"
  value       = "http://localhost:${var.external_port}"
}
