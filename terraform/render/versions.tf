terraform {
  required_version = ">= 1.5.0"

  required_providers {
    render = {
      source  = "render-oss/render"
      version = "~> 1.9.0"
    }
  }

  # Configuración recomendada para equipo: backend remoto
  # backend "s3" o "azurerm" o "remote" (Terraform Cloud)
}

provider "render" {
  # Las credenciales se toman por defecto de las variables de entorno:
  # RENDER_API_KEY y RENDER_OWNER_ID
}
