# Infraestructura como Código (IaC) — CoffeeQueue

Este directorio contiene la implementación de **Infraestructura como Código (IaC)** para el proyecto **CoffeeQueue**, correspondiente a la **Consigna 16** y el rol de **Integrante 3** del trabajo práctico de DevOps.

---

## 📋 Consigna y Objetivos (Integrante 3)

> **Pregunta disparadora**: *¿Cómo crear y reproducir un entorno sin configuraciones manuales?*
> 
> **Objetivos prácticos**:
> 1. Crear recursos de infraestructura mediante código declarativo con Terraform y Docker.
> 2. Configurar contenedores interconectados (`redis`, `api`, `front`, `nginx`) y una red Docker propia.
> 3. Cambiar una propiedad en el código (`nginx_external_port`), revisar el `plan` generado por Terraform y aplicar la modificación.
> 4. Eliminar por completo el entorno de práctica con `destroy`.
> 5. **Entregable**: Infraestructura reproducible y documentada con evidencias claras del ciclo de vida.

---

## 💡 Conceptos Fundamentales de IaC

- **Declaratividad**: En lugar de ejecutar scripts imperativos con pasos manuales (`docker run`, `docker network create`), se describe el **estado final deseado** de la infraestructura. Terraform calcula qué acciones son necesarias para alcanzar dicho estado.
- **Idempotencia**: Ejecutar el mismo código múltiples veces produce exactamente el mismo resultado sin efectos secundarios ni duplicaciones innecesarias.
- **Gestión de Estado (`terraform.tfstate`)**: Terraform mantiene un registro del estado real de los recursos para comparar la realidad contra la configuración deseada y planificar únicamente los cambios requeridos.
- **Reproducibilidad y Control de Versiones**: Toda la infraestructura está versionada en Git, lo que permite a cualquier miembro del equipo o pipeline de CI/CD clonar el repositorio y desplegar un entorno idéntico en minutos.

---

## 🏗️ Arquitectura de la Infraestructura

```text
Host (localhost:8080 o 8081)
       │ (HTTP)
       ▼
┌────────────────────────────────────────────────────────┐
│ Red Docker: coffeequeue-net-dev                        │
│                                                        │
│  ┌────────────────────────┐                            │
│  │ coffeequeue-nginx-dev  │ (Proxy inverso / Gateway)  │
│  └───────────┬────────────┘                            │
│              │                                         │
│      ┌───────┴───────┐                                 │
│      ▼               ▼                                 │
│ ┌──────────────┐ ┌──────────────┐                      │
│ │    front     │ │     api      │                      │
│ │ (React 19)   │ │ (Express 5)  │                      │
│ └──────────────┘ └───────┬──────┘                      │
│                          ▼                             │
│                  ┌──────────────┐                      │
│                  │    redis     │ (Base de datos)      │
│                  └───────┬──────┘                      │
│                          ▼                             │
│                  [Volumen datos]                       │
└────────────────────────────────────────────────────────┘
```

---

## 🛠️ Estructura de Archivos

| Archivo | Propósito |
| --- | --- |
| `versions.tf` | Versión requerida de Terraform (`>= 1.5.0`) y configuración del provider `kreuzwerker/docker`. |
| `variables.tf` | Variables parametrizadas (puerto de Nginx, imágenes, entorno, base de datos). |
| `main.tf` | Definición de recursos: red Docker, volumen, imágenes y contenedores. |
| `outputs.tf` | Valores de salida tras la aplicación (URLs de acceso, nombres de contenedores, puerto activo). |
| `terraform.tfvars.example` | Plantilla de ejemplo para sobreescribir variables localmente. |
| `.gitignore` | Exclusión de archivos de estado local (`*.tfstate`) y carpetas temporales (`.terraform/`). |

---

## 🚀 Guía de Ejecución Paso a Paso

### 1. Prerrequisitos
- **Docker Engine o Docker Desktop** en ejecución.
- **Terraform** instalado (`>= 1.5.0`). Para verificar:
  ```bash
  terraform version
  docker info
  ```

### 2. Inicialización (`terraform init`)
Descarga e inicializa el proveedor de Docker configurado:
```bash
cd terraform
terraform init
```

### 3. Planificación Inicial (`terraform plan`)
Genera y previsualiza las acciones que Terraform llevará a cabo sin modificar nada aún:
```bash
terraform plan -out=tfplan
```
*Salida esperada:* `Plan: 10 to add, 0 to change, 0 to destroy.`

### 4. Creación del Entorno (`terraform apply`)
Aplica el plan para crear la red, el volumen, descargar las imágenes e instanciar los 4 contenedores:
```bash
terraform apply tfplan
```
Al finalizar, Terraform mostrará los `outputs`:
```text
Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:

api_orders_url = "http://localhost:8080/api/orders"
app_url = "http://localhost:8080"
container_names = {
  "api" = "coffeequeue-api-dev"
  "front" = "coffeequeue-front-dev"
  "nginx" = "coffeequeue-nginx-dev"
  "redis" = "coffeequeue-redis-dev"
}
current_nginx_external_port = 8080
docker_network_name = "coffeequeue-net-dev"
```

### 5. Verificación de Funcionamiento
Probar la conectividad y respuesta del entorno en el puerto 8080:
```bash
# Probar el Frontend
curl -I http://localhost:8080/

# Probar la API de pedidos
curl http://localhost:8080/api/orders
```
O abrir [http://localhost:8080](http://localhost:8080) en el navegador para interactuar con la interfaz gráfica.

---

## 🔄 Demostración de Cambio de Propiedad (Requisito Consigna 16)

La consigna solicita: *"cambiar una propiedad, revisar el plan y eliminar el entorno de práctica."*

Para demostrar esto de forma tangible, modificamos la propiedad `nginx_external_port` cambiando del puerto **8080** al puerto **8081**:

### Paso A: Revisar el Plan con el cambio
```bash
terraform plan -var="nginx_external_port=8081"
```
*Evidencia en la salida del plan:*
Terraform detecta que el único cambio requerido es en el contenedor Nginx:
```text
~ resource "docker_container" "nginx" {
    ~ ports {
        ~ external = 8080 -> 8081
          internal = 80
        # (3 unchanged attributes hidden)
      }
  }

Plan: 0 to add, 1 to change, 0 to destroy.
```

### Paso B: Aplicar el cambio
```bash
terraform apply -var="nginx_external_port=8081" -auto-approve
```

### Paso C: Comprobar el cambio en vivo
```bash
# El puerto 8080 ya no responde:
curl -I http://localhost:8080/  # Connection refused o timeout

# El puerto 8081 responde con éxito:
curl -I http://localhost:8081/  # HTTP/1.1 200 OK
curl http://localhost:8081/api/orders
```

---

## 🧹 Destrucción del Entorno de Práctica (`terraform destroy`)

Para cumplir con la última parte de la consigna (*"eliminar el entorno de práctica"*):
```bash
terraform destroy -auto-approve
```
*Salida esperada:*
```text
Destroy complete! Resources: 10 destroyed.
```
Todos los contenedores, redes y volúmenes creados por Terraform se limpian completamente, dejando el sistema en su estado original sin residuos manuales.

---

## 📌 Guía para Integrantes 4 (Testing e Integración) y 5 (Documentación y Exposición)

### Para el Integrante 4 (Integración):
- Esta implementación se encuentra en la rama `feature/iac`.
- Para integrarla a `main`, abrir un Pull Request hacia `main` sin conflictos, ya que todos los archivos se encuentran aislados en la carpeta `terraform/` y `.gitignore`.
- Las pruebas automáticas de CI o de integración pueden ejecutar `cd terraform && terraform init && terraform validate`.

### Para el Integrante 5 (Documentación y Diapositivas):
- **Capturas de pantalla recomendadas para la presentación:**
  1. Captura de `terraform plan`: mostrando los 10 recursos a crear de forma declarativa.
  2. Captura de `terraform apply`: mostrando la creación exitosa y los `outputs` con las URLs.
  3. Captura del navegador en `http://localhost:8080`: el tablero de CoffeeQueue activo y funcional.
  4. Captura del diff de `terraform plan -var="nginx_external_port=8081"`: resaltando el cambio `8080 -> 8081`.
  5. Captura de `terraform destroy`: demostrando cómo se destruye el entorno efímero en segundos.
- **Punto clave a exponer**: Explicar cómo IaC resuelve la fragilidad de configurar entornos manualmente, garantizando que cualquier integrante del equipo disponga de exactamente el mismo entorno con un solo comando.
