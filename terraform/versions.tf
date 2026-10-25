terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {
  # Por defecto en Linux/WSL usa unix:///var/run/docker.sock
  # Si se requiere sobreescribir el socket o pipe de Docker:
  # host = "unix:///var/run/docker.sock"
}
