variable "environment" {
  description = "Entorno de despliegue (ej. dev, prod)"
  type        = string
  default     = "prod"
}

variable "render_region" {
  description = "Región de Render donde se desplegarán los recursos (oregon, ohio, frankfurt, singapore)"
  type        = string
  default     = "oregon"
}

variable "service_plan" {
  description = "Plan de cómputo en Render (free, starter, standard, etc.)"
  type        = string
  default     = "starter"
}

variable "image_api" {
  description = "URL de la imagen en GHCR para la API REST"
  type        = string
  default     = "ghcr.io/tomas-lp/devops-2026-tp1/coffeequeue-api:latest"
}

variable "image_front" {
  description = "URL de la imagen en GHCR para el Frontend"
  type        = string
  default     = "ghcr.io/tomas-lp/devops-2026-tp1/coffeequeue-front:latest"
}

variable "image_nginx" {
  description = "URL de la imagen en GHCR para el Reverse Proxy Nginx"
  type        = string
  default     = "ghcr.io/tomas-lp/devops-2026-tp1/coffeequeue-nginx:latest"
}
