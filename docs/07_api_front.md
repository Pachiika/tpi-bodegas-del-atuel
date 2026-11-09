# 7. API y front

## 7.1 Arquitectura

```
Navegador ──HTTP/JSON──> front (nginx, HTML+JS) ──fetch──> API (FastAPI) ──psycopg 3 + pool──> PostgreSQL
                         front/js/api.js                     app/repositorio/*.py              rol app_rw
```

```
api/
├── app/
│   ├── main.py            arma la app, CORS, manejadores de error, routers
│   ├── config.py          configuración desde variables de entorno (nunca credenciales en el código)
│   ├── db.py              pool de conexiones (psycopg_pool) y transacciones explícitas
│   ├── errores.py         traducción SQLSTATE -> HTTP
│   ├── esquemas.py        modelos de entrada (pydantic): solo forma y tipos, ninguna regla de negocio
│   ├── paginacion.py      ?pagina=&tamanio= (máx. 100)
│   ├── repositorio/       CAPA DE ACCESO A DATOS: una función por consulta, todo el SQL vive acá
│   │   ├── vinos.py  clientes.py  comprobantes.py  documentos.py  reportes.py  catalogos.py
│   └── routers/           controladores HTTP (no contienen SQL)
├── tests/                 pytest (19 pruebas)
├── Dockerfile  requirements.txt  pytest.ini  .env.example
```

**Decisiones.**
- **Driver nativo, sin ORM.** psycopg 3 con SQL escrito a mano y legible en `app/repositorio/`.
- **Consultas parametrizadas.** Ningún valor del usuario se concatena en el SQL:
  - todos viajan como `%s` / `%(nombre)s`, y psycopg 3 los manda al servidor **separados** de la sentencia
    (protocolo extendido);
  - los filtros opcionales del catálogo no arman SQL dinámico: la sentencia es fija y cada filtro se anula
    con `(%(tipo)s IS NULL OR v.tipo = %(tipo)s)`.
- **Pool de conexiones.**
  - Usa `psycopg_pool.ConnectionPool` (entre 1 y 10 conexiones, configurable).
  - Cada request pide prestada una conexión con la dependencia `get_conn` y la devuelve al terminar.
- **Transacciones explícitas.**
  - Las conexiones están en autocommit, así que una sentencia suelta se confirma sola.
  - Las operaciones de varias sentencias usan `with transaccion(conn):`, que emite `BEGIN` y luego
    `COMMIT`, o `ROLLBACK` ante cualquier excepción. Esto vale para:
    - la venta (cabecera + renglones);
    - el alta de un vino (vino + composición + maridajes);
  - Si el constraint trigger diferido de RN-05 falla al hacer COMMIT, también hay ROLLBACK.
- **La API no recalcula nada.**
  - En una venta solo envía cliente, sala, vino y cantidad. Precio, descuento, subtotales, total y stock
    los calcula la base.
  - Para procesar un documento llama a `CALL sp_procesar_transferencia(%s)`.
- **Rol con privilegios mínimos.**
  - Se conecta como `app_rw`, que no es dueño ni superusuario.
  - `GET /salud` lo muestra (`"usuario": "app_rw", "es_superusuario": false`) y verifica que no pueda escribir en
    `auditoria_precio`.

## 7.2 Endpoints

Documentación interactiva **Swagger** en `http://localhost:8000/docs` (OpenAPI en `/openapi.json`). Son 30 rutas.

| Recurso | Método y ruta | Descripción |
|---|---|---|
| Salud | `GET /salud` | Verifica la conexión y muestra con qué rol se conecta |
| Vinos | `GET /vinos?tipo=&cepa=&bodega=&anada=&nombre=&pagina=&tamanio=` | Catálogo con filtros y paginación (`total` incluido) |
| | `GET /vinos/{cod}` | Ficha: composición con porcentajes, maridajes y stock |
| | `POST /vinos` | Alta con composición y maridajes en una transacción (RN-05) |
| | `PUT /vinos/{cod}` | Modificación; el cambio de precio queda auditado (RN-13) |
| | `DELETE /vinos/{cod}` | Baja; 409 si tiene movimientos (RN-14) |
| | `GET /vinos/{cod}/auditoria-precio` | Historial de precios |
| Clientes | `GET /clientes?tipo=&q=` · `GET /clientes/{id}` · `POST` · `PUT /clientes/{id}` · `DELETE /clientes/{id}` | CRUD de los tres tipos (una sola tabla); el descuento lo asigna la base y el CHECK `ck_cliente_datos_tipo` controla los datos de cada tipo |
| Comprobantes | `POST /comprobantes` · `GET /comprobantes/{nro}` · `GET /comprobantes?id_cliente=&id_sala=` | Venta completa en una transacción; 409 sin stock |
| Transferencias | `POST /transferencias` · `GET /transferencias?estado=&id_sala=` · `GET /transferencias/{nro}` | Alta (nace en confección) y consulta |
| | `POST /transferencias/{nro}/renglones` · `DELETE /transferencias/{nro}/renglones/{cod}` | Carga de renglones (solo en confección, RN-12) |
| | `POST /transferencias/{nro}/terminar` · `POST /transferencias/{nro}/procesar` | Cambios de estado; procesar invoca el procedimiento |
| Ingresos | `POST /ingresos` · `POST /ingresos/{cod}/renglones` · `POST /ingresos/{cod}/terminar` · `POST /ingresos/{cod}/procesar` · `GET /ingresos` · `GET /ingresos/{cod}` | Mismo circuito |
| Reportes | `GET /reportes/top-vinos` (S1) · `/ventas-por-sala?meses=3` (S8) · `/vinos-sin-stock?id_sala=` (S6) · `/transportista-activo` (S7) · `/trazabilidad/{cod}` (S9 + ingresos, transferencias, ventas por sala, precios) | Solo lectura |
| Catálogos | `GET /salas` · `/cepas` · `/bodegas` · `/maridajes` · `/transportistas` · `/localidades` | Para los combos del front |

## 7.3 Traducción de errores

`app/errores.py` registra un manejador para `psycopg.Error`. Toma el **SQLSTATE** y responde así:

| Situación | SQLSTATE | HTTP |
|---|---|---|
| UNIQUE violado | 23505 | 409 |
| FK violada (dato inexistente o con dependientes) | 23503 (o 23001 en PostgreSQL 17+) | 409 |
| CHECK violado | 23514 | 422 |
| NOT NULL violado | 23502 | 422 |
| Regla de negocio (RAISE EXCEPTION en trigger o procedimiento) | P0001 | 409 con el mensaje de la regla |
| Texto con formato inválido para el tipo (p. ej. ENUM) | 22P02 | 400 |
| Fallo de serialización / deadlock | 40001 / 40P01 | 503 + `Retry-After` |
| Permiso denegado | 42501 | 403 |
| Pool agotado o base caída | — | 503 |
| Otro | — | 500 (sin detalles internos; queda en el log) |

Cuerpo de error (ejemplo real, venta sin stock):

```json
{"error": "regla_de_negocio", "sqlstate": "P0001",
 "mensaje": "Stock insuficiente del vino 1 en la sala 1: hay 16, se pidieron 5000 (RN-09)",
 "detalle": null, "restriccion": null, "tabla": null}
```

## 7.4 Pruebas automáticas

`api/tests/test_api.py` tiene **19 pruebas**, todas en verde. **9 provocan a propósito la violación de una
regla de la base** (prefijo `test_REGLA_`) y verifican el código HTTP y que no queden datos a medias.

```
test_salud_usa_rol_sin_privilegios PASSED
test_catalogo_filtros_y_paginacion PASSED
test_ficha_vino_con_composicion PASSED
test_inyeccion_sql_se_trata_como_texto PASSED
test_cliente_recibe_descuento_de_la_base PASSED
test_venta_ok_calcula_la_base_y_descuenta_stock PASSED
test_cambio_de_precio_queda_auditado PASSED
test_circuito_transferencia PASSED
test_REGLA_venta_sin_stock_409_y_sin_datos_a_medias PASSED      (P0001 -> 409; la cabecera no queda)
test_REGLA_precio_negativo_422 PASSED                           (23514 ck_vino_precio_positivo -> 422)
test_REGLA_composicion_que_no_suma_100 PASSED                   (constraint trigger diferido -> 409)
test_REGLA_cambio_de_estado_invalido PASSED                     (terminar sin renglones, procesar en confección)
test_REGLA_renglon_en_documento_procesado PASSED                (RN-12)
test_REGLA_borrar_vino_con_movimientos_409 PASSED               (23503 RESTRICT -> 409)
test_REGLA_documento_duplicado_409 PASSED                       (23505 -> 409)
test_REGLA_estado_invalido_400 PASSED                           (ENUM: 22P02 -> 400)
test_REGLA_distribuidor_sin_zona_422 PASSED                     (23514 ck_cliente_datos_tipo -> 422)
test_circuito_ingreso_suma_stock_en_deposito PASSED
test_alta_exportador PASSED
19 passed
```

```bash
docker compose exec api pytest -v
```

Las pruebas corren contra la base real. Crean sus propios datos (una localidad, una sala, una bodega y cepas
con un sufijo aleatorio) y al final borran lo que pueden. El vino al que se le cambió el precio queda, porque
`app_rw` no puede borrar la auditoría (es justamente lo que se quiere demostrar). Conviene correrlas antes de
cargar el dataset definitivo o sobre una base de prueba.

## 7.5 Demostración de inyección SQL fallida

Se envía un valor malicioso al filtro `nombre` del catálogo:

```bash
curl "http://localhost:8000/vinos?nombre=x%27%3B%20DROP%20TABLE%20vino%3B%20--"
#  nombre = x'; DROP TABLE vino; --
{"datos":[],"pagina":1,"tamanio":20,"total":0}

curl "http://localhost:8000/vinos?tamanio=1"
{"datos":[{"cod_vino":573,"nombre":"Blend de Tintas Clásico", ...}], ... "total":600}   # la tabla sigue ahí
```

La consulta es `... AND lower(v.nombre) LIKE lower(%(nombre)s::text) || '%'`. El texto viaja como **valor del
parámetro**, no como parte del SQL. PostgreSQL lo compara literalmente como un nombre de vino (no hay
ninguno que empiece con `x'; DROP...`) y devuelve 0 filas. Aunque se lograra inyectar, `app_rw` no es dueña
de las tablas y no podría hacer `DROP TABLE`. Lo verifica también `test_inyeccion_sql_se_trata_como_texto`.
*(Captura para el informe: ejecutar el curl o abrir la URL en el navegador.)*

## 7.6 Front

HTML + CSS + JavaScript sin frameworks, servido por nginx. Todas las llamadas pasan por
[`front/js/api.js`](../front/js/api.js). La URL de la API se configura en `front/js/config.js`; en Docker, el
contenedor la reescribe con la variable `API_URL`.

| Pantalla | Qué hace | Captura |
|---|---|---|
| Catálogo | Listado paginado con filtros por nombre, tipo, cepa, bodega y añada; ficha con composición, maridajes y stock | [1_catalogo.png](capturas/1_catalogo.png) |
| Alta y edición de vino | Formulario con composición de cepas y maridajes. **No valida la suma**: la base rechaza y se muestra su mensaje ("...suman 70.00 y deben sumar 100 (RN-05)") | [2_vino_error.png](capturas/2_vino_error.png) |
| Nueva venta | Cliente, sala y vinos. Muestra el total **calculado por la base**, o el error de stock tal como lo devuelve la API | [3_venta_ok.png](capturas/3_venta_ok.png), [3_venta_sin_stock.png](capturas/3_venta_sin_stock.png) |
| Transferencias | Crear, cargar renglones y Terminar o Procesar, con botones que se habilitan según el estado | [4_transferencias.png](capturas/4_transferencias.png) |
| Tablero | Top 10 vinos, gráfico de barras de ventas por sala en el último trimestre y vinos sin stock en una sala | [5_tablero.png](capturas/5_tablero.png) |

**El front no calcula importes, descuentos ni stock.**
- Solo formatea los números que recibe (`toLocaleString`).
- El ancho de las barras del gráfico es una escala visual sobre los montos que devuelve `/reportes/ventas-por-sala`.
- Los errores se muestran **sin reemplazarlos por un mensaje genérico**: `409 · <mensaje de la regla> [SQLSTATE P0001]`.

![Venta sin stock](capturas/3_venta_sin_stock.png)
