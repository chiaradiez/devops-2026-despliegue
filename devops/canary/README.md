# Canary Deployment local de CoffeeQueue

Esta práctica ejecuta dos versiones del frontend de CoffeeQueue al mismo tiempo y
usa Nginx para repartir las solicitudes entre ellas. La configuración inicial envía
el 90 % del tráfico a V1 y el 10 % a V2.

El entorno es local, independiente del Compose original y no modifica los despliegues
de producción, los workflows de GitHub Actions, la API ni el modelo de Redis.

## ¿Qué es Canary Deployment?

Canary Deployment es una estrategia de entrega progresiva: una versión nueva recibe
primero una porción pequeña del tráfico real. Si las métricas y pruebas son correctas,
se aumenta su participación; si aparece un problema, se corta su tráfico y se vuelve
a la versión estable.

Reduce el alcance de una falla frente a reemplazar el 100 % de la aplicación de una
vez. En este TP el procedimiento se demuestra con cuatro estados: 100/0, 90/10,
50/50 y 0/100.

## Arquitectura

La arquitectura original es:

```text
Navegador -> Nginx :80 -> Frontend React/Vite
                       -> API Express :3000 -> Redis :6379
```

El stack Canary queda así:

```text
                                  +-> Frontend V1 :80
Navegador -> Nginx :8080 -- / ----|
                   |              +-> Frontend V2 :80
                   |
                   +---- /api/ ------> API Express :3000 -> Redis :6379
```

- **Docker Compose** crea una red, un volumen y cinco servicios exclusivos del TP.
- **Nginx proxy** aplica los pesos solamente a las solicitudes del frontend.
- **Frontend V1** conserva la interfaz original y responde `X-App-Version: v1`.
- **Frontend V2** usa el mismo build, agrega la etiqueta visible
  `CoffeeQueue V2 - Canary` y responde `X-App-Version: v2`.
- **API** es única y se conecta a un único Redis. Por eso los pedidos creados desde
  cualquiera de las versiones se ven en el mismo almacenamiento.
- **Redis** usa el volumen independiente `coffeequeue-canary-redis-data`.

La cabecera de versión la agrega el servidor que realmente entregó el frontend. El
proxy no elige ni inventa ese valor: propaga la cabecera del upstream seleccionado.

## Archivos

```text
devops/canary/
  docker-compose.canary.yml  Stack local independiente
  nginx.conf                 Proxy de frontend y ruta exclusiva de API
  front-v1.conf              Servidor estático V1 y cabecera v1
  front-v2.conf              Servidor estático V2, etiqueta y cabecera v2
  Set-CanaryTraffic.ps1      Valida y recarga un perfil sin detener el stack
  test-canary.ps1            Prueba estadística, variantes y API compartida
  weights/
    active.conf              Perfil activo; inicialmente 90/10
    100-0.conf               Solo V1
    90-10.conf               Canary inicial
    50-50.conf               Mitad para cada versión
    0-100.conf               Solo V2
```

No se modificó ningún archivo existente fuera de `devops/canary`.

## Requisitos

- Docker Desktop iniciado y con Docker Compose v2.
- PowerShell 5.1 o posterior.
- Puerto `8080` libre.

Todos los comandos siguientes se ejecutan desde la raíz del repositorio.

## Inicio rápido: 90 % V1 y 10 % V2

Preparar explícitamente el perfil inicial, construir y levantar:

```powershell
.\devops\canary\Set-CanaryTraffic.ps1 90-10
docker compose -f .\devops\canary\docker-compose.canary.yml up -d --build
docker compose -f .\devops\canary\docker-compose.canary.yml ps
```

Abrir [http://localhost:8080](http://localhost:8080). Al actualizar varias veces,
la etiqueta de V2 aparecerá aproximadamente en una de cada diez respuestas. Para
evitar la caché del navegador durante la demostración se puede usar `Ctrl+F5`.

Consultar manualmente qué versión respondió:

```powershell
$response = Invoke-WebRequest http://localhost:8080/
$response.Headers["X-App-Version"]
```

Detener el entorno sin borrar los pedidos guardados:

```powershell
docker compose -f .\devops\canary\docker-compose.canary.yml down
```

No usar `down -v`: ese parámetro borraría el volumen Canary de Redis.

## Validación 90/10

El script usa solicitudes `HEAD` para medir el reparto sin descargar mil veces todo
el HTML. Después obtiene muestras HTML, comprueba que cabecera y etiqueta coincidan,
y verifica que `/api/orders` responda desde la API compartida y no desde los
frontends.

```powershell
.\devops\canary\test-canary.ps1
```

Por defecto envía 1000 solicitudes, espera 10 % de V2 y admite una tolerancia de
cinco puntos porcentuales. Los números observados pueden variar; no tienen que ser
exactamente 900 y 100.

Una salida correcta tiene esta forma (los valores son ilustrativos):

```text
Total de solicitudes: 1000
Version V1: 902 solicitudes (90,2 %)
Version V2: 98 solicitudes (9,8 %)
Errores HTTP o de red: 0
Respuestas sin version valida: 0
Resultado: distribucion y rutas validadas correctamente.
```

Para comprobar también creación y eliminación de un pedido temporal:

```powershell
.\devops\canary\test-canary.ps1 -TestOrders
```

Esta opción crea únicamente un pedido llamado `Prueba Canary` y elimina exactamente
ese mismo pedido al terminar. No borra ni modifica pedidos preexistentes.

## Despliegue progresivo

`Set-CanaryTraffic.ps1` copia el perfil elegido, ejecuta `nginx -t` dentro del proxy
y solo entonces hace `nginx -s reload`. La recarga no detiene los otros servicios.
Si la validación falla, el script restaura el archivo anterior.

### 1. Estado original: 100 % V1

```powershell
.\devops\canary\Set-CanaryTraffic.ps1 100-0
.\devops\canary\test-canary.ps1 -ExpectedV2Percent 0
```

### 2. Canary inicial: 90 % V1 / 10 % V2

```powershell
.\devops\canary\Set-CanaryTraffic.ps1 90-10
.\devops\canary\test-canary.ps1 -ExpectedV2Percent 10
```

### 3. Aumento: 50 % V1 / 50 % V2

```powershell
.\devops\canary\Set-CanaryTraffic.ps1 50-50
.\devops\canary\test-canary.ps1 -ExpectedV2Percent 50
```

### 4. Despliegue completo: 100 % V2

```powershell
.\devops\canary\Set-CanaryTraffic.ps1 0-100
.\devops\canary\test-canary.ps1 -ExpectedV2Percent 100
```

En los extremos se usa `down` para excluir el servidor con 0 %. Nginx no admite
`weight=0`. El script exige exactamente cero respuestas de la versión desactivada.

## Rollback

Si V2 presenta un problema, cortar inmediatamente su tráfico nuevo:

```powershell
.\devops\canary\Set-CanaryTraffic.ps1 100-0
.\devops\canary\test-canary.ps1 -ExpectedV2Percent 0
```

El primer comando valida y recarga Nginx. El segundo envía 1000 solicitudes y falla
si alguna llega a V2. No es necesario detener V2, la API, Redis ni V1.

Para volver al Canary inicial:

```powershell
.\devops\canary\Set-CanaryTraffic.ps1 90-10
.\devops\canary\test-canary.ps1 -ExpectedV2Percent 10
```

## Validaciones técnicas adicionales

Validar la definición de Compose:

```powershell
docker compose -f .\devops\canary\docker-compose.canary.yml config --quiet
```

Validar Nginx y consultar el upstream real de cada solicitud:

```powershell
docker compose -f .\devops\canary\docker-compose.canary.yml exec -T proxy nginx -t
docker compose -f .\devops\canary\docker-compose.canary.yml logs proxy
```

Las líneas del proxy incluyen `upstream=<IP:puerto>` y `version=v1|v2`. Para revisar
el estado compartido de pedidos sin modificarlo:

```powershell
Invoke-RestMethod http://localhost:8080/api/orders
```

### Estado de validación de esta implementación

Validaciones ejecutadas el 21 de octubre de 2026:

- `docker compose ... config --quiet`: correcto.
- Sintaxis de los dos scripts PowerShell: correcta.
- `npm run lint` del frontend: correcto.
- `npm run build` del frontend: correcto con Vite 8.3.0.
- `npm test` de la API: 5 pruebas correctas.
- Los cinco contenedores del stack: activos.
- `nginx -t` dentro del proxy: correcto.
- `test-canary.ps1` ejecutado con Windows PowerShell 5.1 contra el stack real: contó
  900 respuestas V1 y 100 V2 de 1000, sin errores ni cabeceras desconocidas.
- API y Redis compartidos: pedido temporal creado y eliminado correctamente mediante
  `test-canary.ps1 -TestOrders`.

## Distribución por solicitud y limitaciones

Esta implementación usa el balanceo ponderado round-robin de Nginx **por solicitud**.
No implementa afinidad por cookie, IP ni sesión. Un mismo usuario puede recibir V1
en una recarga y V2 en la siguiente. Esto simplifica la demostración y hace medible
el reparto, pero debe explicarse explícitamente.

Otras limitaciones:

- Es un laboratorio local, no una configuración productiva completa.
- No incluye métricas, alertas, TLS, réplicas del proxy ni despliegue cloud.
- V1 y V2 comparten actualmente el mismo build; V2 se diferencia al servir el HTML.
  Esto evita tocar React. Si en el futuro fueran builds realmente distintos, habría
  que cuidar que los recursos estáticos de una página no se pidan a la otra versión,
  por ejemplo usando afinidad o rutas de assets versionadas.
- La prueba valida proporciones HTTP, no experiencia de usuario, rendimiento ni
  compatibilidad entre navegadores.

## Decisiones y problemas encontrados

- El Compose original publica el puerto 80. Para poder mantener ambos entornos sin
  conflicto, Canary publica el puerto 8080 y usa nombres de red/volumen propios.
- La configuración original del frontend no identifica versiones. En vez de editar
  archivos compartidos o duplicar React, cada servicio monta su propia configuración
  Nginx desde esta carpeta.
- Usar `VITE_APP_VERSION` habría requerido modificar el Dockerfile y el componente
  React compartidos. La inyección al servir `index.html` produce el cambio visual
  pedido y mantiene todo el trabajo Canary aislado.
- Las rutas `/api/` se declaran antes del frontend y apuntan a un upstream exclusivo,
  de modo que nunca participan del reparto V1/V2.
- Los perfiles 100/0 y 0/100 usan `down`, porque `weight=0` no es válido en Nginx.
- Docker Desktop no estaba iniciado durante la primera validación. Después de
  iniciarlo, se comprobaron los cinco contenedores, Nginx, el reparto 90/10, la API y
  Redis.
- Windows PowerShell 5.1 no cargaba automáticamente `System.Net.Http`; el script ahora
  carga explícitamente el ensamblado antes de crear `HttpClient`.
- `npm ci` informó vulnerabilidades en dependencias ya declaradas por el proyecto. No
  se ejecutó `npm audit fix`, porque actualizar dependencias compartidas excede el
  alcance de Canary y podría afectar el trabajo existente.

## Guion sugerido para una demo de 3 a 5 minutos

1. **Arquitectura (30 s):** mostrar este diagrama y explicar que ambos frontends
   comparten una API y un Redis.
2. **Canary 90/10 (60 s):** ejecutar `Set-CanaryTraffic.ps1 90-10`, abrir la app y
   mostrar la cabecera o la etiqueta V2. Ejecutar `test-canary.ps1`.
3. **Pedidos compartidos (45 s):** crear un pedido desde la interfaz, recargar hasta
   cambiar de versión y mostrar que el pedido sigue allí.
4. **Progresión (45 s):** aplicar `50-50` y ejecutar la prueba con
   `-ExpectedV2Percent 50`.
5. **Rollback (45 s):** explicar una falla simulada, aplicar `100-0` y demostrar con
   `-ExpectedV2Percent 0` que V2 no recibe tráfico nuevo.
6. **Cierre (20 s):** aclarar que el reparto es por solicitud y que el entorno local
   está aislado del Compose y del despliegue productivo.
