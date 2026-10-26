# ── 1. Proyecto en Render para agrupar recursos ───────────────────────
resource "render_project" "coffeequeue" {
  name = "coffeequeue-${var.environment}"
  environments = {
    "${var.environment}" = {
      name             = var.environment
      protected_status = "unprotected"
    }
  }
}

# ── 2. Base de datos Redis administrada ────────────────────────────────
resource "render_redis" "redis" {
  name              = "coffeequeue-redis-${var.environment}"
  plan              = "free"
  region            = var.render_region
  max_memory_policy = "noeviction"

  ip_allow_list = [
    {
      cidr_block  = "0.0.0.0/0"
      description = "Acceso interno para servicios del stack"
    }
  ]
}

# ── 3. Servicio Web: API REST ──────────────────────────────────────────
resource "render_web_service" "api" {
  name   = "coffeequeue-api-${var.environment}"
  plan   = var.service_plan
  region = var.render_region

  runtime_source = {
    image = {
      image_url = var.image_api
      tag       = var.image_tag
    }
  }

  env_vars = {
    "PORT" = {
      value = "3000"
    }
    "REDIS_HOST" = {
      value = render_redis.redis.connection_info.internal_connection_string
    }
  }
}

# ── 4. Servicio Web: Frontend React ────────────────────────────────────
resource "render_web_service" "front" {
  name   = "coffeequeue-front-${var.environment}"
  plan   = var.service_plan
  region = var.render_region

  runtime_source = {
    image = {
      image_url = var.image_front
      tag       = var.image_tag
    }
  }
}

# ── 5. Servicio Web: Nginx Reverse Proxy (Gateway) ─────────────────────
resource "render_web_service" "nginx" {
  name   = "coffeequeue-nginx-${var.environment}"
  plan   = var.service_plan
  region = var.render_region

  runtime_source = {
    image = {
      image_url = var.image_nginx
      tag       = var.image_tag
    }
  }

  env_vars = {
    "API_URL" = {
      value = render_web_service.api.url
    }
    "FRONT_URL" = {
      value = render_web_service.front.url
    }
  }
}
