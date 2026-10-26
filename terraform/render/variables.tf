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
  description = "URL de la imagen en GHCR para la API REST (sin tag)"
  type        = string
  default     = "ghcr.io/tomas-lp/devops-2026-tp1/coffeequeue-api"
}

variable "image_front" {
  description = "URL de la imagen en GHCR para el Frontend (sin tag)"
  type        = string
  default     = "ghcr.io/tomas-lp/devops-2026-tp1/coffeequeue-front"
}

variable "image_nginx" {
  description = "URL de la imagen en GHCR para el Reverse Proxy Nginx (sin tag)"
  type        = string
  default     = "ghcr.io/tomas-lp/devops-2026-tp1/coffeequeue-nginx"
}

variable "image_tag" {
  description = "Tag de las imágenes a desplegar (ej. latest o un SHA corto)"
  type        = string
  default     = "latest"
}
