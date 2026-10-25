locals {
  api_image_id   = var.use_remote_images ? docker_image.api_remote[0].image_id : docker_image.api_local[0].image_id
  front_image_id = var.use_remote_images ? docker_image.front_remote[0].image_id : docker_image.front_local[0].image_id
}

# ── Red Docker para comunicación interna ──────────────────────────────
resource "docker_network" "coffeequeue_net" {
  name = "coffeequeue-net-${var.environment}"
}

# ── Volumen para persistencia de Redis ─────────────────────────────────
resource "docker_volume" "redis_data" {
  name = "coffeequeue-redis-data-${var.environment}"
}

# ── Imágenes Docker ───────────────────────────────────────────────────
resource "docker_image" "redis" {
  name         = var.image_redis
  keep_locally = true
}

resource "docker_image" "nginx" {
  name         = var.image_nginx
  keep_locally = true
}

# Imágenes API (remota o compilación local condicional)
resource "docker_image" "api_remote" {
  count        = var.use_remote_images ? 1 : 0
  name         = var.image_api
  keep_locally = true
}

resource "docker_image" "api_local" {
  count = var.use_remote_images ? 0 : 1
  name  = "coffeequeue-api:${var.environment}"
  build {
    context = abspath("${path.module}/../api")
  }
}

# Imágenes Frontend (remota o compilación local condicional)
resource "docker_image" "front_remote" {
  count        = var.use_remote_images ? 1 : 0
  name         = var.image_front
  keep_locally = true
}

resource "docker_image" "front_local" {
  count = var.use_remote_images ? 0 : 1
  name  = "coffeequeue-front:${var.environment}"
  build {
    context = abspath("${path.module}/../front")
  }
}

# ── Contenedor: Redis ─────────────────────────────────────────────────
resource "docker_container" "redis" {
  name    = "coffeequeue-redis-${var.environment}"
  image   = docker_image.redis.image_id
  command = ["redis-server", "--protected-mode", "no"]
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.coffeequeue_net.name
    aliases = ["redis"]
  }

  volumes {
    volume_name    = docker_volume.redis_data.name
    container_path = "/data"
  }
}

# ── Contenedor: API REST ──────────────────────────────────────────────
resource "docker_container" "api" {
  name    = "coffeequeue-api-${var.environment}"
  image   = local.api_image_id
  restart = "unless-stopped"

  env = [
    "REDIS_HOST=redis",
    "REDIS_PORT=6379",
    "REDIS_DB=${var.redis_db}",
    "PORT=${var.api_internal_port}"
  ]

  networks_advanced {
    name    = docker_network.coffeequeue_net.name
    aliases = ["api"]
  }

  depends_on = [
    docker_container.redis
  ]
}

# ── Contenedor: Frontend React ────────────────────────────────────────
resource "docker_container" "front" {
  name    = "coffeequeue-front-${var.environment}"
  image   = local.front_image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.coffeequeue_net.name
    aliases = ["front"]
  }
}

# ── Contenedor: Nginx Reverse Proxy (Gateway) ─────────────────────────
resource "docker_container" "nginx" {
  name    = "coffeequeue-nginx-${var.environment}"
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  ports {
    internal = 80
    external = var.nginx_external_port
  }

  networks_advanced {
    name    = docker_network.coffeequeue_net.name
    aliases = ["nginx"]
  }

  upload {
    content = file("${path.module}/../nginx/nginx.conf")
    file    = "/etc/nginx/nginx.conf"
  }

  depends_on = [
    docker_container.front,
    docker_container.api
  ]
}
