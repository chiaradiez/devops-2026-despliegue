output "app_url" {
  description = "URL pública de acceso a la aplicación vía Gateway Nginx"
  value       = render_web_service.nginx.url
}

output "api_url" {
  description = "URL directa del servicio de API REST"
  value       = render_web_service.api.url
}

output "front_url" {
  description = "URL directa del Frontend React"
  value       = render_web_service.front.url
}

output "service_id_api" {
  description = "ID del servicio API en Render"
  value       = render_web_service.api.id
}

output "service_id_front" {
  description = "ID del servicio Frontend en Render"
  value       = render_web_service.front.id
}

output "service_id_nginx" {
  description = "ID del servicio Nginx en Render"
  value       = render_web_service.nginx.id
}

output "redis_id" {
  description = "ID del servicio Redis en Render"
  value       = render_redis.redis.id
}
