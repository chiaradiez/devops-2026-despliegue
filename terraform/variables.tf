variable "environment" {
  description = "Identificador del entorno de infraestructura"
  type        = string
  default     = "dev"
}

variable "nginx_external_port" {
  description = "Puerto expuesto en el host para acceder a la aplicación mediante Nginx (Propiedad a modificar para la demostración de IaC)"
  type        = number
  default     = 8080
}

variable "use_remote_images" {
  description = "Indica si se deben descargar imágenes de GHCR (true) o compilar localmente (false)"
  type        = bool
  default     = true
}

variable "image_api" {
  description = "Imagen de Docker para la API REST"
  type        = string
  default     = "ghcr.io/tomas-lp/devops-2026-tp1/coffeequeue-api:latest"
}

variable "image_front" {
  description = "Imagen de Docker para el Frontend"
  type        = string
  default     = "ghcr.io/tomas-lp/devops-2026-tp1/coffeequeue-front:latest"
}

variable "image_nginx" {
  description = "Imagen base para Nginx reverse proxy"
  type        = string
  default     = "nginx:alpine"
}

variable "image_redis" {
  description = "Imagen base para el almacenamiento Redis"
  type        = string
  default     = "redis:alpine"
}

variable "redis_db" {
  description = "Base de datos lógica de Redis para CoffeeQueue"
  type        = number
  default     = 0
}

variable "api_internal_port" {
  description = "Puerto interno en el que escucha la API"
  type        = number
  default     = 3000
}
