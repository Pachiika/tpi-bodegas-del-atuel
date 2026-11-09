# 8. Despliegue en la nube

> **Estado: guía preparada, despliegue PENDIENTE.** Los pasos de abajo los ejecuta el grupo con sus propias
> cuentas. Al terminar, completar la sección 8.7 con las URL reales y las capturas.

## 8.1 Comparación de proveedores

Límites consultados en noviembre de 2026. Los planes gratuitos cambian seguido: **verificarlos de nuevo antes de elegir**.

| | **Render** (elegido) | **Neon** | VPS con Docker (p. ej. créditos de estudiante) |
|---|---|---|---|
| Base gratis | Postgres 1 GB, **vence a los 30 días** (14 días de gracia para pasar a pago; después se borra); una por workspace; sin backups | 1 GB por proyecto, 100 CU-h/mes, sin vencimiento, se suspende tras 5 min sin uso | La que entre en el disco |
| API y front | Web service con Docker (se duerme tras 15 min sin tráfico, ~1 min para despertar) + static site, HTTPS automático | No (solo base) | `docker compose` + Caddy/nginx con Let's Encrypt |
| **Restringir el puerto de la base** | **Sí, en todos los planes**: allowlist de IP por base; sin reglas no hay acceso externo. La API entra por la **red interna** | IP Allow **solo en el plan Scale** (pago) | Sí: no publicar el 5432 (solo red interna de Docker) + firewall |
| Tarjeta | No para el plan free | No | Depende del proveedor |
| Fuentes | render.com/docs/free · render.com/docs/inbound-ip-rules | neon.com/faqs/free-plan-limits-and-quotas · neon.com/docs/introduction/ip-allow | — |

**Decisión: Render.**
- Permite tener base, API y front en un mismo lugar, con HTTPS incluido.
- Es el único plan gratuito de los comparados que permite **cerrar el puerto de la base a internet**,
  requisito del enunciado.
- El dataset completo (≈ 96 MB) entra en 1 GB, así que **no hace falta una carga reducida**.

Contras asumidos:
- La base gratuita vence a los 30 días. Por eso se crea **dentro de los 30 días previos a la defensa**,
  o se pasa al plan pago más barato durante un mes.
- No incluye backups, que hacemos nosotros con `pg_dump` (ver [09_backup.md](09_backup.md)).
- La API se duerme: hay que abrirla un minuto antes de la demo.

Alternativa si Render no sirve: Neon para la base (pero sin restricción por IP en el plan gratuito, que es un
requisito) o un VPS con el mismo `docker-compose.yml`, sin publicar el puerto 5432.

## 8.2 Base de datos y roles

1. Render → **New → Postgres** (o **New → Blueprint** con el [`render.yaml`](../render.yaml) del repo): nombre `bodegas-db`, base `bodegas`, PostgreSQL 16, plan Free.
2. El usuario que crea Render es el **dueño** de la base: cumple el rol de `bodega_owner`.
3. Copiar la **External Database URL** (solo para trabajar desde la PC) y agregar `?sslmode=require`.
4. En **Access Control** agregar solo la IP pública del grupo (`curl ifconfig.me`) mientras se aplican las migraciones.

```bash
export OWNER_URL="postgresql://<usuario>:<pass>@<host-externo>/bodegas?sslmode=require"
export APP_RW_PASSWORD="<generar una larga>"  APP_RO_PASSWORD="<otra>"
bash db/nube/aplicar_migraciones.sh       # crea app_rw/app_ro, aplica 001..008 en orden, corre db_tests
```

El script muestra `ssl=true`, que confirma que la conexión está cifrada.
Si el proveedor no permite `CREATE ROLE` al usuario dueño, se crean los roles desde su panel y se vuelve a correr.

## 8.3 Carga de datos

Carga completa (entra en el plan):

```bash
DATABASE_URL_OWNER="$OWNER_URL" SEED_FECHA_REFERENCIA=$(date +%F) python db/seed/seed.py todo
```

Las consultas de control tienen que dar 0 en todas las filas (capturar la salida).

## 8.4 API y front

**API**: Render → New → **Web Service** → repo → Root Directory `api`, runtime **Docker**. Variables de entorno (en el panel, nunca en el repo):

| Variable | Valor |
|---|---|
| `DB_HOST` | **Internal** hostname de la base (red privada de Render) |
| `DB_PORT` / `DB_NAME` | 5432 / bodegas |
| `DB_USER` | **app_rw** (nunca el dueño) |
| `DB_PASSWORD` | la de `APP_RW_PASSWORD` |
| `DB_SSLMODE` | `require` si la conexión interna lo acepta; si no, `prefer` (el tráfico interno no sale a internet) |
| `CORS_ORIGINS` | `https://bodegas-front.onrender.com` (la URL real del front) |

Verificar `https://<api>.onrender.com/salud`. Tiene que responder `"usuario": "app_rw", "es_superusuario": false`.

**Front**: New → **Static Site** → Root Directory `front` → Build command:
`echo "window.CONFIG = { API_URL: \"$API_URL\" };" > js/config.js` → Publish directory `.` → variable
`API_URL=https://<api>.onrender.com`. Abrir la URL del front y comprobar que el indicador diga "API: ok (app_rw)".

## 8.5 Restringir el acceso a la base

1. Cuando termine la carga, en **Access Control** de la base **borrar todas las reglas**. Sin reglas, Render bloquea toda conexión externa.
   La API sigue funcionando porque usa la red interna.
2. Comprobar que una conexión no autorizada es rechazada. Desde la PC, o con datos móviles para tener otra IP:

```bash
psql "$OWNER_URL" -c "select 1"
# debe fallar (conexión rechazada / no permitida)   <- captura para el informe
```

Para volver a administrar la base se agrega la IP del grupo por un rato y después se quita.

## 8.6 Reglas de la base funcionando en la nube

- Desde el front publicado: **Nueva venta** con una cantidad mayor al stock. Tiene que aparecer
  `409 · Stock insuficiente del vino ... (RN-09) [SQLSTATE P0001]` (captura).
- Procesar una transferencia y ver el cambio de estado.
- Backup y restauración: ver [09_backup.md](09_backup.md), sección "En la nube".

## 8.7 Resultado (completar)

| Ítem | Valor / evidencia |
|---|---|
| URL del front | `https://...` |
| URL de la API / Swagger | `https://.../docs` |
| `/salud` en la nube | captura |
| Conexión cifrada (`ssl=true`) | captura de `aplicar_migraciones.sh` |
| Conexión no autorizada rechazada | captura |
| Venta sin stock rechazada en la nube | captura |
| Backup restaurado y conteos iguales | captura |
| Fecha de creación de la base (vence a los 30 días) | `AAAA-MM-DD` |

## 8.8 Secretos

- `.env` está en `.gitignore`. En el repo solo existen `.env.example` y `api/.env.example`, con valores de ejemplo.
- Las migraciones **no contienen contraseñas**: los roles se crean sin contraseña y se la asigna `00_init.sh`
  (local) o `aplicar_migraciones.sh` (nube), tomándola de variables de entorno.
- Antes de entregar, revisar que no haya secretos en todo el historial:
  `git log -p | grep -iE "password|postgresql://[^ ]*:[^ ]*@"` (solo tienen que aparecer placeholders).
- Si alguna vez se subió una contraseña real: **cambiarla** (rotarla). Borrarla del historial no alcanza,
  porque cualquiera pudo haberla copiado.
