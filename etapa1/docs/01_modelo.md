# 1. Modelo de datos

## 1.1 Diagrama entidad-relación

- DER del grupo: [`der/Modelo_Integrador.pdf`](der/Modelo_Integrador.pdf). Muestra las cardinalidades
  mínimas y máximas, la entidad débil Parcela y la jerarquía de Cliente.
- Archivo fuente (dbdiagram.io): [`der/modelo.dbml`](der/modelo.dbml).

El estado de ingresos y transferencias es un ENUM y el cliente tiene la columna `descuento`, porque las dos
cosas las pide el enunciado (se explican en 1.4).

## 1.2 Esquema relacional (26 tablas)

PK en **negrita**, FK con `→`.

| Área | Tablas |
|---|---|
| Geografía y salas | localidad(**codigo_postal**, nombre, provincia, encargado_regional) · sala_venta(**id_sala**, calle, numero, dia_cierre, cp_localidad→localidad) · empleado(**cuit**, nombre, fecha_ingreso, salario, id_sala→sala_venta) |
| Viñedos | finca(**id_finca**, nombre, superficie_ha, departamento, provincia) · parcela(**id_finca→finca, nro_parcela**, superficie_ha, anio_plantacion, id_cepa→cepa) · cepa(**id_cepa**, nombre, tipo) |
| Elaboración | bodega(**cuit**, razon_social, domicilio) · lote_uva(**nro_lote**, (id_finca, nro_parcela)→parcela, campania, fecha_cosecha, kilos_cosechados, cuit_bodega_destino→bodega) · analisis_calidad(**id_analisis**, nro_lote→lote_uva, fecha, grado_brix, ph, acidez_total) |
| Vinos | vino(**cod_vino**, nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega→bodega) · composicion_vino(**cod_vino→vino, id_cepa→cepa**, porcentaje) · maridaje(**id_maridaje**, nombre, temperatura_servicio) · vino_maridaje(**cod_vino→vino, id_maridaje→maridaje**) |
| Clientes | cliente(**id_cliente**, nombre_o_razon_social, tipo_doc, nro_doc, direccion, cp_localidad→localidad, fecha_alta, tipo_cliente, descuento, zona_cobertura, nro_habilitacion, pais_destino_principal) · permiso_exportacion(**codigo**, id_cliente→cliente, fecha_emision, fecha_vencimiento) |
| Ventas | comprobante(**nro_comprobante**, fecha, id_cliente→cliente, id_sala→sala_venta, subtotal, descuento, total) · renglon_comprobante(**nro_comprobante→comprobante, cod_vino→vino**, cantidad, precio_unitario, descuento_aplicado, subtotal) |
| Stock y logística | stock_sala(**id_sala→sala_venta, cod_vino→vino**, cantidad) · stock_deposito(**cod_vino→vino**, cantidad) · transportista(**codigo_transporte**, razon_social, cuit, email, telefono, domicilio) · transportista_cubre_localidad(**codigo_transporte→transportista, cp_localidad→localidad**) · ingreso(**codigo_ingreso**, fecha, estado, codigo_transporte→transportista, cuit_bodega→bodega) · renglon_ingreso(**codigo_ingreso→ingreso, cod_vino→vino**, cantidad) · transferencia(**nro_transferencia**, id_sala→sala_venta, fecha_confeccion, estado) · renglon_transferencia(**nro_transferencia→transferencia, cod_vino→vino**, cantidad) |
| Auditoría | auditoria_precio(**id_auditoria**, cod_vino→vino, precio_anterior, precio_nuevo, fecha_hora, usuario) |

La sección 5 del enunciado lista 29 entidades. Quedan **26 tablas** porque Socio, Distribuidor y Exportador
no tienen tabla propia: los tres están dentro de `cliente` (se justifica en 1.4). Todas las demás entidades
tienen su tabla, y cada relación N:M también (`composicion_vino`, `vino_maridaje`,
`transportista_cubre_localidad`).

El detalle de cada columna (tipo, nulos, valor por defecto, restricciones) está en el
[diccionario de datos](02_diccionario_datos.md).

## 1.3 Normalización

- **1FN**: ninguna columna guarda una lista de valores. Las relaciones N:M (las cepas de un vino, los
  maridajes, las localidades que cubre cada transportista) tienen su propia tabla.
- **2FN**: en las tablas con clave compuesta, todos los atributos dependen de la clave completa. Por ejemplo,
  en `renglon_comprobante (nro_comprobante, cod_vino)` la cantidad y el precio dependen del par. El nombre
  del vino depende solo de `cod_vino`, por eso está en `vino` y no se repite en cada renglón.
- **3FN**: no hay atributos que dependan de otro atributo que no sea clave. El caso típico es la regla
  **RN-02**: el encargado regional depende de la localidad y no de la sala. Por eso está en `localidad`, y la
  sala solo guarda `cp_localidad`.

### Dependencias funcionales

Una flecha `A → B` quiere decir que el valor de A determina el valor de B. En cada tabla, el lado izquierdo
es la clave (o una clave candidata) y el lado derecho son todos los demás atributos.

| Tabla | Dependencia funcional |
|---|---|
| localidad | codigo_postal → nombre, provincia, encargado_regional |
| sala_venta | id_sala → calle, numero, dia_cierre, cp_localidad |
| empleado | cuit → nombre, fecha_ingreso, salario, id_sala |
| finca | id_finca → nombre, superficie_ha, departamento, provincia |
| parcela | (id_finca, nro_parcela) → superficie_ha, anio_plantacion, id_cepa |
| cepa | id_cepa → nombre, tipo |
| lote_uva | nro_lote → id_finca, nro_parcela, campania, fecha_cosecha, kilos_cosechados, cuit_bodega_destino. Clave candidata: (id_finca, nro_parcela, campania) → nro_lote (RN-04) |
| analisis_calidad | id_analisis → nro_lote, fecha, grado_brix, ph, acidez_total |
| bodega | cuit → razon_social, domicilio |
| vino | cod_vino → nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega. Clave candidata: (nombre, anada, volumen_ml) → cod_vino |
| composicion_vino | (cod_vino, id_cepa) → porcentaje |
| maridaje | id_maridaje → nombre, temperatura_servicio |
| cliente | id_cliente → todos los demás datos. Clave candidata: (tipo_doc, nro_doc) → id_cliente |
| permiso_exportacion | codigo → id_cliente, fecha_emision, fecha_vencimiento |
| comprobante | nro_comprobante → fecha, id_cliente, id_sala, subtotal, descuento, total |
| renglon_comprobante | (nro_comprobante, cod_vino) → cantidad, precio_unitario, descuento_aplicado, subtotal |
| stock_sala | (id_sala, cod_vino) → cantidad |
| stock_deposito | cod_vino → cantidad |
| transportista | codigo_transporte → razon_social, cuit, email, telefono, domicilio |
| ingreso | codigo_ingreso → fecha, estado, codigo_transporte, cuit_bodega |
| renglon_ingreso | (codigo_ingreso, cod_vino) → cantidad |
| transferencia | nro_transferencia → id_sala, fecha_confeccion, estado |
| renglon_transferencia | (nro_transferencia, cod_vino) → cantidad |
| auditoria_precio | id_auditoria → cod_vino, precio_anterior, precio_nuevo, fecha_hora, usuario |

`vino_maridaje` y `transportista_cubre_localidad` no tienen atributos fuera de la clave, por eso no tienen
dependencias que revisar.

**Dependencias parciales: no quedan.** Solo puede haberlas en tablas con clave compuesta
(`parcela`, `composicion_vino`, `renglon_comprobante`, `renglon_ingreso`, `renglon_transferencia`,
`stock_sala`). En todas, cada atributo depende del par completo y no de una sola parte. Por ejemplo, el
porcentaje depende de (vino, cepa) juntos: un mismo vino tiene un porcentaje distinto para cada cepa. Los
datos que dependen de una sola parte de la clave (el nombre del vino, el nombre de la cepa) están en
`vino` y `cepa`.

**Dependencias transitivas: no quedan.** El único caso que lo habría sido es
`sala_venta → cp_localidad → encargado_regional`. Se resolvió dejando `encargado_regional` en `localidad`
(RN-02). Lo mismo con `finca → departamento → provincia`, que se explica abajo como excepción. Los importes
guardados (subtotal, total) también son excepciones elegidas a propósito, y están justificados abajo.

**Desnormalizaciones que hicimos a propósito:**

- **Departamento y provincia dentro de `finca`.** En rigor, la provincia depende del departamento y no de
  la finca, así que una tabla `departamento` aparte estaría en 3FN. Lo dejamos así porque el enunciado lo
  describe como un dato de la finca, son pocas fincas (60, todas de Mendoza) y ninguna consulta trabaja con
  departamentos. Si hiciera falta, se puede separar en otra tabla sin cambiar el resto.
- **Importes guardados en el comprobante** (`subtotal`, `descuento`, `total`) y el `subtotal` del renglón.
  Se podrían calcular, pero se guardan porque el comprobante es un documento histórico y porque sumar
  500.000 renglones en cada consulta sería lento. Para que nunca queden mal:
  - nadie los escribe a mano: los triggers los recalculan siempre (RN-08);
  - el CHECK `total = subtotal - descuento` no deja guardar un total incorrecto;
  - una consulta de control de la carga lo verifica en todos los datos.
- **`descuento` dentro de `cliente`.** A primera vista parece una dependencia transitiva
  (`id_cliente → tipo_cliente → descuento`), porque el descuento depende del tipo (10, 20 o 30 %). Se
  guarda igual porque **no es siempre el del tipo**: la consulta U6 sube a 35 % el descuento de algunos
  exportadores. Entonces es un dato propio de cada cliente. El valor por defecto lo pone un trigger según el
  tipo (RN-06).
- `precio_unitario` y `descuento_aplicado` del renglón **no** son redundantes: son el precio y el descuento
  del día de la venta. Si después cambia el precio del vino, las ventas viejas no cambian.

## 1.4 Decisiones de diseño

### Jerarquía de clientes: una sola tabla

El enunciado pide elegir cómo guardar los tres tipos de cliente (socio, distribuidor y exportador) y
justificar la elección. Vimos tres opciones:

| Opción | Ventajas | Desventajas |
|---|---|---|
| **Una sola tabla con la columna `tipo_cliente`** (elegida) | Es simple, no hace falta hacer joins y las ventas apuntan a una sola tabla | Algunas columnas quedan en NULL según el tipo |
| Una tabla por cada tipo | No hay NULL | `comprobante` tendría que apuntar a tres tablas y los datos comunes se repiten |
| Tabla general + una tabla por tipo | No hay NULL ni datos repetidos | Para ver un cliente completo hay que hacer un join |

Elegimos **una sola tabla** porque cada tipo tiene muy pocos datos propios: el distribuidor tiene dos (zona
de cobertura y número de habilitación), el exportador uno (país de destino) y el socio ninguno.

Para que los NULL no queden mal cargados, agregamos un **CHECK** (`ck_cliente_datos_tipo`):
- un socio no puede tener zona, habilitación ni país;
- un distribuidor tiene que tener zona y habilitación, y no país;
- un exportador tiene que tener país, y no zona ni habilitación.

Los permisos de exportación apuntan a `cliente`, pero la clave foránea no sabe de qué tipo es el cliente.
Por eso un **trigger** (`fn_trg_permiso_solo_exportador`) no deja cargar un permiso a un cliente que no es
exportador (RN-07).

También agregamos la columna **`descuento`** al cliente, porque el enunciado la pide y porque la consulta U6
cambia el descuento de algunos exportadores. Si no se carga, un trigger pone el descuento que corresponde a
su tipo (RN-06).

### Claves

| Tabla | Clave | Por qué |
|---|---|---|
| bodega, empleado | **CUIT** | Es único y siempre tiene 11 dígitos |
| localidad | **código postal** | Es un dato real que no cambia |
| permiso_exportacion | **código** del permiso | Lo da el organismo y ya es único |
| vino, cliente, comprobante, ingreso, transferencia, sala, finca, lote, transportista | `SERIAL` (número automático) | No tienen un dato propio que sea único y estable (por ejemplo, el nombre de un vino se repite en distintas añadas) |
| cepa, maridaje, analisis_calidad, auditoria_precio | Número automático (`id_...`) | El nombre de una cepa o de un maridaje podría cambiar, y un análisis o una auditoría no tienen ningún dato propio que los identifique |
| parcela | (id_finca, nro_parcela) | Es **entidad débil**: el número de parcela solo tiene sentido dentro de su finca |
| renglones, stock y tablas N:M | Las dos claves foráneas juntas | Un vino aparece una sola vez en cada comprobante, sala o transferencia |

Además pusimos `UNIQUE` en datos que no se pueden repetir, por ejemplo `cliente (tipo_doc, nro_doc)` y
`vino (nombre, anada, volumen_ml)`.

### Tipos de datos

- **Dinero**: `NUMERIC(10,2)` y `NUMERIC(12,2)`, **nunca FLOAT**, porque FLOAT no guarda exacto valores como
  0,10 y los errores se van sumando. Los importes del comprobante usan el dominio `dinero_dom`, que no
  acepta negativos.
- **Porcentajes**: el de la composición del vino es `INT` y el descuento usa el dominio `porcentaje_dom`
  (de 0 a 100).
- **Fechas**: `DATE` cuando no hace falta la hora (alta de cliente, cosecha, permisos) y `TIMESTAMP` en los
  documentos (comprobante, ingreso, transferencia).
- **Estado de ingresos y transferencias**: dos ENUM, `estado_ingreso` y `estado_transferencia`, con los
  valores `en_confeccion`, `terminado` y `procesado`. Así el estado no puede ser un texto cualquiera.
- **Otros tipos** (tipo de vino, de cepa, de cliente, día de cierre): `VARCHAR` con un `CHECK ... IN (...)`
  que limita los valores posibles.
- **CUIT**: dominio `cuit_dom`, un `VARCHAR(11)` que solo acepta 11 números.

### Atributos derivados

Un atributo derivado es el que se puede calcular a partir de otros datos. Algunos se guardan y otros se
calculan cada vez que hacen falta:

| Atributo | ¿Se guarda? | Por qué y cómo se mantiene bien |
|---|---|---|
| `comprobante.subtotal`, `descuento` y `total` | Sí | Es un documento histórico y sumar los renglones en cada consulta sería lento. Los recalculan los triggers (RN-08) y el CHECK `total = subtotal - descuento` impide un total incorrecto |
| `renglon_comprobante.subtotal` | Sí | Lo calcula el trigger al insertar el renglón (RN-08) |
| `renglon_comprobante.precio_unitario` y `descuento_aplicado` | Sí | Son el precio y el descuento del momento de la venta; si se calcularan, las ventas viejas cambiarían al subir el precio |
| `cliente.descuento` | Sí | Puede cambiar por cliente (U6). Si no se carga, un trigger pone el del tipo (RN-06), y el dominio `porcentaje_dom` lo limita de 0 a 100 |
| Antigüedad del empleado | **No** | Cambia todos los días, por eso se calcula con `fn_antiguedad_anios` a partir de `fecha_ingreso` |
| Stock total de un vino | **No** | Se calcula con una vista que suma `stock_deposito` y `stock_sala`; así no puede quedar distinto del stock real |
| Rendimiento (kg por hectárea) de una parcela | **No** | Se calcula en la consulta S10 con `kilos_cosechados` y `superficie_ha` |

La idea es simple: se guarda lo que es **histórico** o muy caro de recalcular, y siempre con un trigger o un
CHECK que impide que quede mal. Se calcula lo que **cambia con el tiempo** o con otros datos.

### Qué pasa al borrar (acciones referenciales)

| Caso | ON DELETE | Ejemplos |
|---|---|---|
| Datos con historia (ventas, movimientos) | **RESTRICT**: no deja borrar | comprobante→cliente, renglón→vino, vino→bodega (RN-14) |
| Datos que no existen sin su "padre" | **CASCADE**: se borran con él | renglón→comprobante, composición→vino, parcela→finca |
| Catálogos | **RESTRICT** | composición→cepa, cliente→localidad |

En todas usamos `ON UPDATE CASCADE`, por si hay que corregir una clave como un CUIT o un código postal.
Por ejemplo, al borrar un comprobante se borran sus renglones (consulta D1), pero no se puede borrar un vino
que ya se vendió.

## 1.5 Crear la base desde cero

Se ejecutan las migraciones en orden:

```powershell
Get-ChildItem db\migrations\0*.sql | ForEach-Object { psql -U postgres -v ON_ERROR_STOP=1 -d bodegas -f $_.FullName }
```

Las migraciones (001 a 009) se aplican sin errores sobre una base vacía, y después `db/tests/db_tests.sql`
da los 69 casos esperados.
