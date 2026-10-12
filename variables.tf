variable "container_name" {
  description = "Nom du conteneur Web"
  type        = string
  default     = "tp-iac-nginx"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]*$", var.container_name))
    error_message = "Le nom du conteneur contient des caractères non autorisés."
  }
}

variable "external_port" {
  description = "Port HTTP exposé sur la machine locale"
  type        = number
  default     = 8080

  validation {
    condition     = var.external_port >= 1024 && var.external_port <= 65535
    error_message = "Le port doit être compris entre 1024 et 65535."
  }
}
