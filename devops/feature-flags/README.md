# Feature Flags en CoffeeQueue

## Qué son y para qué sirven

Una Feature Flag es una configuración que permite decidir en tiempo de ejecución si un cambio de producto se muestra. En DevOps permite desplegar código y activar la funcionalidad en otro momento, probarla con un grupo acotado y apagarla rápidamente si hace falta. El despliegue instala el código; la activación cambia la configuración.

## Arquitectura implementada

```text
React/Vite ── GET /api/feature-flags?group=... ──> Express ──> Redis
                                                      ▲
PowerShell ── PATCH /api/admin/feature-flags/... ─────┘
```

- La bandera es `show_order_wait_time`.
- Los grupos de demostración son `control` y `beta`. La selección del tablero se guarda en `localStorage` y también puede inicializarse con `?group=beta` o `?group=control`.
- El grupo recibido identifica sólo la variante de la demo; no es una identidad autenticada. El backend lee y evalúa la configuración. `control` permanece apagado; `beta` queda apagado si aún no se guardó un valor.
- Redis conserva la configuración en la clave `feature-flags:show_order_wait_time:beta`. El volumen `redis-data` existente mantiene esos datos al recrear los contenedores.
- Cada cuatro segundos React consulta la API. Si la consulta falla, oculta la función. El tiempo se calcula con `createdAt` real; se actualiza cada minuto, no baja de cero y muestra “Tiempo no disponible” si el pedido no tiene una fecha válida.
- La creación de pedidos ya guardaba `createdAt`, por lo que no se cambió el modelo ni el flujo de pedidos.

## API

Consulta (grupo omitido equivale a `control`):

```http
GET /api/feature-flags?group=beta
```

```json
{"group":"beta","flags":{"show_order_wait_time":false}}
```

Administración de la bandera beta:

```http
PATCH /api/admin/feature-flags/show_order_wait_time
Authorization: Bearer <FEATURE_FLAGS_ADMIN_TOKEN>
Content-Type: application/json

{"group":"beta","enabled":true}
```

El servidor acepta sólo el grupo `beta` para cambios. Si `FEATURE_FLAGS_ADMIN_TOKEN` no está configurado, el endpoint administrativo responde `503`; una credencial ausente o inválida recibe `403`. No se configura ninguna credencial en React ni se cambia la configuración cloud.

## Iniciar con Docker Compose (PowerShell)

Desde la raíz del repositorio:

```powershell
$env:FEATURE_FLAGS_ADMIN_TOKEN = 'token-local-largo-para-la-demo'
docker compose up --build -d
```

Abrí `http://localhost/?group=beta` y elegí Beta en el selector “Grupo demo”. El panel inicial será Beta y la elección se conservará en ese navegador. Cambiar la bandera no requiere reconstruir imágenes ni reiniciar servicios; el token se configura al iniciar la API y sólo protege el endpoint administrativo.

Para iniciar el stack sin habilitar administración, omití `FEATURE_FLAGS_ADMIN_TOKEN` y el endpoint de escritura quedará deshabilitado.

## Consultar, activar y desactivar

El script usa `http://localhost/api` de forma predeterminada, es decir, el Nginx de Compose:

```powershell
$env:FEATURE_FLAGS_ADMIN_TOKEN = 'token-local-largo-para-la-demo'
.\devops\feature-flags\manage-feature-flag.ps1 status
.\devops\feature-flags\manage-feature-flag.ps1 on
.\devops\feature-flags\manage-feature-flag.ps1 off
```

Para una API local distinta, se puede pasar su base URL:

```powershell
.\devops\feature-flags\manage-feature-flag.ps1 status -ApiBaseUrl 'http://localhost:3000/api'
```

La opción `status` es de lectura y no requiere el token. Después de `on` o `off`, esperá hasta cuatro segundos: React detecta el cambio por polling. En Beta el indicador aparece o desaparece; en Control permanece oculto.

## Pruebas

Desde `api`, ejecutar `npm test`. La prueba HTTP de Feature Flags verifica el estado inicial OFF, control siempre OFF, acceso administrativo con y sin token, lectura del valor guardado y activación observada por la API. El mock Redis de esa prueba guarda en un `Map`: valida las llamadas al servicio, pero no reemplaza una prueba de persistencia en disco. Para probar persistencia entre reinicios de contenedor, activar, recrear la API y volver a consultar; Redis conserva la configuración en el volumen existente.

Desde `front`, ejecutar `npm run lint` y `npm run build`. Para comprobar los flujos de pedidos con Redis real, usar las instrucciones de pruebas de integración de la raíz del repositorio y sólo una base Redis de pruebas vacía y exclusiva. Estas comprobaciones no deben ejecutarse contra datos de usuarios.

### Validación de esta implementación

- `api`: `npm test` — 6 pruebas aprobadas.
- `front`: `npm run lint` y `npm run build` — aprobados.
- Script PowerShell: sintaxis validada.
- No se ejecutaron pruebas de integración con Redis real ni una prueba visual de polling en navegador: el daemon de Docker no estaba disponible y no había `redis-server` local. La persistencia mediante volumen y el cambio en una instancia real quedan para probar con Compose disponible.

## Seguridad y limitaciones

- El selector de grupo es para una demostración académica. Como no hay autenticación, cualquier visitante puede seleccionar `beta`; el grupo no otorga privilegios.
- El endpoint de administración requiere un token Bearer que se proporciona mediante una variable de entorno y se compara en el servidor. No guardar un token real en Git. En una demo local, configurarlo sólo en la terminal. No publicar ni exponer este endpoint en producción sin una capa de autenticación apropiada; la configuración de producción permanece fuera de este cambio.
- El polling tiene una demora esperada de hasta cuatro segundos y no usa WebSockets.
- La disponibilidad de Redis es necesaria para administrar cambios. Si falla durante la consulta, la API devuelve OFF para proteger la interfaz.
- La bandera sólo cubre el tiempo de espera; no altera estados, creación ni finalización de pedidos.
