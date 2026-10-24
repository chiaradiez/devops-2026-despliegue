output "app_url" {
  description = "URL principal para acceder al frontend de CoffeeQueue a través del proxy Nginx"
  value       = "http://localhost:${var.nginx_external_port}"
}

output "api_orders_url" {
  description = "URL del endpoint REST para consultar pedidos a través de Nginx"
  value       = "http://localhost:${var.nginx_external_port}/api/orders"
}

output "docker_network_name" {
  description = "Nombre de la red Docker creada para interconectar los servicios"
  value       = docker_network.coffeequeue_net.name
}

output "container_names" {
  description = "Nombres de los contenedores creados en el entorno"
  value = {
    redis = docker_container.redis.name
    api   = docker_container.api.name
    front = docker_container.front.name
    nginx = docker_container.nginx.name
  }
}

output "current_nginx_external_port" {
  description = "Puerto externo configurado actualmente en Nginx (útil para comprobar cambios en el plan)"
  value       = var.nginx_external_port
}
