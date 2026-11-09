# 2. Diccionario de datos

## 2.1 Tipos enumerados

| Tipo | Valores |
|---|---|
| estado_ingreso | en_confeccion, terminado, procesado |
| estado_transferencia | en_confeccion, terminado, procesado |

## 2.2 Dominios

| Dominio | Tipo base | Restricción |
|---|---|---|
| cardinal_number | integer | CHECK ((VALUE >= 0)) |
| cuit_dom | character varying(11) | CHECK (((VALUE)::text ~ '^[0-9]{11}$'::text)) |
| dinero_dom | numeric(12,2) | CHECK ((VALUE >= (0)::numeric)) |
| porcentaje_dom | numeric(5,2) | CHECK (((VALUE >= (0)::numeric) AND (VALUE <= (100)::numeric))) |
| yes_or_no | character varying(3) | CHECK (((VALUE)::text = ANY ((ARRAY['YES'::character varying, 'NO'::character varying])::text[]))) |

## 2.3 Tablas y columnas

| Tabla | Columna | Tipo | Admite nulos | Default | Descripción |
|---|---|---|---|---|---|
| `analisis_calidad` | id_analisis | integer | No | nextval('analisis_calidad_id_analisis_seq'::regclass) | Identificador del análisis de calidad. |
| `analisis_calidad` | nro_lote | integer | No | - | Lote de uva analizado. Un lote puede tener varios análisis. |
| `analisis_calidad` | fecha | date | No | - | Fecha en que se practicó el análisis. |
| `analisis_calidad` | grado_brix | numeric(5,2) | No | - | Grado Brix (contenido de azúcar) de la muestra. |
| `analisis_calidad` | ph | numeric(4,2) | No | - | pH de la muestra. |
| `analisis_calidad` | acidez_total | numeric(5,2) | No | - | Acidez total de la muestra, en g/L. |
| `auditoria_precio` | id_auditoria | integer | No | nextval('auditoria_precio_id_auditoria_seq'::regclass) | Identificador del registro de auditoría. |
| `auditoria_precio` | cod_vino | integer | No | - | Vino cuyo precio cambió. |
| `auditoria_precio` | precio_anterior | numeric(10,2) | No | - | Precio antes del cambio. |
| `auditoria_precio` | precio_nuevo | numeric(10,2) | No | - | Precio después del cambio. |
| `auditoria_precio` | fecha_hora | timestamp without time zone | No | now() | Fecha y hora del cambio. La completa el trigger de auditoría (RN-13). |
| `auditoria_precio` | usuario | character varying(50) | No | SESSION_USER | Usuario de la base que hizo el cambio. Lo completa el trigger de auditoría (RN-13). |
| `bodega` | cuit | cuit_dom | No | - | CUIT de la bodega (11 dígitos). Clave primaria. |
| `bodega` | razon_social | character varying(120) | No | - | Razón social de la bodega. |
| `bodega` | domicilio | character varying(150) | No | - | Domicilio de la bodega. |
| `cepa` | id_cepa | integer | No | nextval('cepa_id_cepa_seq'::regclass) | Identificador de la cepa. |
| `cepa` | nombre | character varying(50) | No | - | Nombre de la cepa (por ejemplo Malbec). |
| `cepa` | tipo | character varying(50) | No | - | Tipo de cepa: tinta o blanca. |
| `cliente` | id_cliente | integer | No | nextval('cliente_id_cliente_seq'::regclass) | Identificador del cliente. |
| `cliente` | nombre_o_razon_social | character varying(120) | No | - | Apellido y nombre, o razón social si es una empresa. |
| `cliente` | tipo_doc | character varying(10) | No | - | Tipo de documento del cliente. |
| `cliente` | nro_doc | character varying(20) | No | - | Número de documento del cliente. |
| `cliente` | direccion | character varying(150) | No | - | Dirección del cliente. |
| `cliente` | cp_localidad | character varying(10) | No | - | Localidad del cliente, por código postal. |
| `cliente` | fecha_alta | date | No | CURRENT_DATE | Fecha de alta del cliente. |
| `cliente` | tipo_cliente | character varying(20) | No | - | Tipo de cliente: socio del club, distribuidor o exportador. Define el descuento. |
| `cliente` | descuento | porcentaje_dom | No | - | Porcentaje de descuento según el tipo de cliente: 10 % socio, 20 % distribuidor, 30 % exportador (RN-06). |
| `cliente` | zona_cobertura | character varying(80) | Sí | - | Solo distribuidores: zona de cobertura. |
| `cliente` | nro_habilitacion | character varying(50) | Sí | - | Solo distribuidores: número de habilitación. |
| `cliente` | pais_destino_principal | character varying(80) | Sí | - | Solo exportadores: país de destino principal. |
| `composicion_vino` | cod_vino | integer | No | - | Vino que se compone. |
| `composicion_vino` | id_cepa | integer | No | - | Cepa que forma parte del vino. |
| `composicion_vino` | porcentaje | integer | No | - | Porcentaje de corte de la cepa en el vino. La suma por vino debe ser 100 (RN-05). |
| `comprobante` | nro_comprobante | integer | No | nextval('comprobante_nro_comprobante_seq'::regclass) | Número del comprobante de venta. |
| `comprobante` | fecha | timestamp without time zone | No | now() | Fecha y hora de la venta. |
| `comprobante` | id_cliente | integer | No | - | Cliente que compró. |
| `comprobante` | id_sala | integer | No | - | Sala de venta donde se realizó la venta. |
| `comprobante` | subtotal | dinero_dom | No | 0 | Importe de los renglones antes del descuento. Lo calcula la base, no se carga a mano (RN-08). |
| `comprobante` | descuento | dinero_dom | No | 0 | Importe del descuento aplicado. Lo calcula la base (RN-08). |
| `comprobante` | total | dinero_dom | No | 0 | Total del comprobante. Lo calcula la base, no se carga a mano (RN-08). |
| `empleado` | cuit | cuit_dom | No | - | CUIT del empleado (11 dígitos). Clave primaria. |
| `empleado` | nombre | character varying(120) | No | - | Nombre del empleado. |
| `empleado` | fecha_ingreso | date | No | - | Fecha de ingreso laboral. Es la base para calcular la antigüedad. |
| `empleado` | salario | numeric(10,2) | No | - | Salario del empleado. |
| `empleado` | id_sala | integer | No | - | Sala donde trabaja. Cada empleado trabaja en una sola sala (RN-03). |
| `finca` | id_finca | integer | No | nextval('finca_id_finca_seq'::regclass) | Identificador de la finca. |
| `finca` | nombre | character varying(80) | No | - | Nombre de la finca. |
| `finca` | superficie_ha | numeric(8,2) | No | - | Superficie total de la finca, en hectáreas. |
| `finca` | departamento | character varying(80) | No | - | Departamento donde se ubica la finca. |
| `finca` | provincia | character varying(80) | No | - | Provincia donde se ubica la finca. |
| `ingreso` | codigo_ingreso | integer | No | nextval('ingreso_codigo_ingreso_seq'::regclass) | Código del ingreso al depósito central. |
| `ingreso` | fecha | timestamp without time zone | No | now() | Fecha del ingreso. |
| `ingreso` | estado | estado_ingreso | No | 'en_confeccion'::estado_ingreso | Estado: en_confeccion, terminado o procesado. Solo avanza en ese orden (RN-10). |
| `ingreso` | codigo_transporte | integer | No | - | Transportista que hizo el traslado. |
| `ingreso` | cuit_bodega | cuit_dom | No | - | Bodega de origen de los vinos. |
| `localidad` | codigo_postal | character varying(10) | No | - | Código postal. Clave natural de la localidad. |
| `localidad` | nombre | character varying(80) | No | - | Nombre de la localidad. |
| `localidad` | provincia | character varying(80) | No | - | Provincia de la localidad. |
| `localidad` | encargado_regional | character varying(120) | No | - | Encargado regional (responsable comercial). Es único por localidad, por eso está acá y no en la sala (RN-02, 3FN). |
| `lote_uva` | nro_lote | integer | No | nextval('lote_uva_nro_lote_seq'::regclass) | Número del lote de uva. |
| `lote_uva` | id_finca | integer | No | - | Finca de la parcela cosechada. Junto con nro_parcela identifica la parcela. |
| `lote_uva` | nro_parcela | integer | No | - | Número de la parcela cosechada dentro de la finca. |
| `lote_uva` | campania | integer | No | - | Año de la campaña (cosecha). Una parcela se cosecha a lo sumo una vez por campaña (RN-04). |
| `lote_uva` | fecha_cosecha | date | No | - | Fecha de cosecha. |
| `lote_uva` | kilos_cosechados | numeric(10,2) | No | - | Kilos de uva cosechados. Siempre positivo (RN-15). |
| `lote_uva` | cuit_bodega_destino | cuit_dom | No | - | Bodega a la que se entregó el lote. |
| `maridaje` | id_maridaje | integer | No | nextval('maridaje_id_maridaje_seq'::regclass) | Identificador del maridaje. |
| `maridaje` | nombre | character varying(80) | No | - | Nombre del maridaje (por ejemplo carnes rojas). |
| `maridaje` | temperatura_servicio | integer | No | - | Temperatura de servicio sugerida, en °C. |
| `parcela` | id_finca | integer | No | - | Finca a la que pertenece la parcela. Junto con nro_parcela forma la clave (entidad débil). |
| `parcela` | nro_parcela | integer | No | - | Número de la parcela dentro de la finca. |
| `parcela` | superficie_ha | numeric(8,2) | No | - | Superficie de la parcela, en hectáreas. |
| `parcela` | anio_plantacion | integer | No | - | Año de plantación. |
| `parcela` | id_cepa | integer | No | - | Cepa plantada. Cada parcela tiene una sola cepa (RN-04). |
| `permiso_exportacion` | codigo | character varying(30) | No | - | Código del permiso de exportación. |
| `permiso_exportacion` | id_cliente | integer | No | - | Exportador titular del permiso. Un exportador puede tener varios (RN-07). |
| `permiso_exportacion` | fecha_emision | date | No | - | Fecha de emisión del permiso. |
| `permiso_exportacion` | fecha_vencimiento | date | No | - | Fecha de vencimiento. Debe ser posterior a la emisión (RN-07). |
| `renglon_comprobante` | nro_comprobante | integer | No | - | Comprobante al que pertenece el renglón. |
| `renglon_comprobante` | cod_vino | integer | No | - | Vino vendido en el renglón. |
| `renglon_comprobante` | cantidad | integer | No | - | Botellas vendidas. Positiva y no mayor al stock de la sala (RN-09, RN-15). |
| `renglon_comprobante` | precio_unitario | numeric(10,2) | No | - | Precio unitario del vino al momento de la venta. |
| `renglon_comprobante` | descuento_aplicado | porcentaje_dom | No | - | Porcentaje de descuento del renglón, según el tipo de cliente (RN-06). |
| `renglon_comprobante` | subtotal | dinero_dom | No | - | Importe del renglón. Lo calcula la base (RN-08). |
| `renglon_ingreso` | codigo_ingreso | integer | No | - | Ingreso al que pertenece el renglón. |
| `renglon_ingreso` | cod_vino | integer | No | - | Vino que ingresa. |
| `renglon_ingreso` | cantidad | integer | No | - | Cantidad de botellas que ingresan. Positiva (RN-15). |
| `renglon_transferencia` | nro_transferencia | integer | No | - | Transferencia a la que pertenece el renglón. |
| `renglon_transferencia` | cod_vino | integer | No | - | Vino solicitado. |
| `renglon_transferencia` | cantidad | integer | No | - | Cantidad de botellas solicitadas. Positiva (RN-15). |
| `sala_venta` | id_sala | integer | No | nextval('sala_venta_id_sala_seq'::regclass) | Identificador de la sala de venta. |
| `sala_venta` | calle | character varying(80) | No | - | Calle de la dirección de la sala. |
| `sala_venta` | numero | character varying(10) | No | - | Número de la dirección de la sala. |
| `sala_venta` | dia_cierre | character varying(15) | No | - | Día de cierre semanal de la sala. |
| `sala_venta` | cp_localidad | character varying(10) | No | - | Localidad donde está la sala. Cada sala está en una sola localidad (RN-02). |
| `stock_deposito` | cod_vino | integer | No | - | Vino almacenado en el depósito central. |
| `stock_deposito` | cantidad | integer | No | 0 | Botellas en el depósito central. Nunca negativa (RN-09). |
| `stock_sala` | id_sala | integer | No | - | Sala que tiene el stock. |
| `stock_sala` | cod_vino | integer | No | - | Vino en stock. |
| `stock_sala` | cantidad | integer | No | 0 | Botellas en la sala. Nunca negativa (RN-09). |
| `transferencia` | nro_transferencia | integer | No | nextval('transferencia_nro_transferencia_seq'::regclass) | Número de solicitud de la transferencia. |
| `transferencia` | id_sala | integer | No | - | Sala que solicita los vinos al depósito central. |
| `transferencia` | fecha_confeccion | timestamp without time zone | No | now() | Fecha de confección. La fija un trigger con la fecha actual y no se puede modificar (RN-11). |
| `transferencia` | estado | estado_transferencia | No | 'en_confeccion'::estado_transferencia | Estado: en_confeccion, terminado o procesado. Solo avanza en ese orden (RN-11). |
| `transportista` | codigo_transporte | integer | No | nextval('transportista_codigo_transporte_seq'::regclass) | Código de la empresa de transporte. |
| `transportista` | razon_social | character varying(120) | No | - | Razón social del transportista. |
| `transportista` | cuit | cuit_dom | No | - | CUIT del transportista (11 dígitos). |
| `transportista` | email | character varying(100) | No | - | Correo electrónico del transportista. |
| `transportista` | telefono | character varying(30) | No | - | Teléfono del transportista. |
| `transportista` | domicilio | character varying(150) | No | - | Domicilio del transportista. |
| `transportista_cubre_localidad` | codigo_transporte | integer | No | - | Transportista que presta el servicio. |
| `transportista_cubre_localidad` | cp_localidad | character varying(10) | No | - | Localidad alcanzada por el servicio del transportista. |
| `vino` | cod_vino | integer | No | nextval('vino_cod_vino_seq'::regclass) | Código del vino. |
| `vino` | nombre | character varying(100) | No | - | Nombre comercial del vino. |
| `vino` | tipo | character varying(20) | No | - | Tipo de vino: tinto, blanco, rosado o espumante. |
| `vino` | anada | integer | No | - | Añada (año de la cosecha del vino). |
| `vino` | volumen_ml | integer | No | - | Presentación en ml (por ejemplo 375, 750 o 1500). |
| `vino` | graduacion | numeric(4,2) | No | - | Graduación alcohólica, entre 5 y 20 (RN-15). |
| `vino` | precio | numeric(10,2) | No | - | Precio de venta, igual para todas las salas y mayor que cero (RN-01). Sus cambios se auditan (RN-13). |
| `vino` | cuit_bodega | cuit_dom | No | - | Bodega que elabora el vino. |
| `vino_maridaje` | cod_vino | integer | No | - | Vino recomendado. |
| `vino_maridaje` | id_maridaje | integer | No | - | Maridaje recomendado para el vino. |

## 2.4 Restricciones

| Tabla | Nombre | Tipo | Definición |
|---|---|---|---|
| analisis_calidad | ck_analisis_acidez | CHECK | CHECK ((acidez_total > (0)::numeric)) |
| analisis_calidad | ck_analisis_brix | CHECK | CHECK (((grado_brix >= (0)::numeric) AND (grado_brix <= (40)::numeric))) |
| analisis_calidad | ck_analisis_ph | CHECK | CHECK (((ph >= (2)::numeric) AND (ph <= (5)::numeric))) |
| analisis_calidad | analisis_calidad_nro_lote_fkey | FOREIGN KEY | FOREIGN KEY (nro_lote) REFERENCES lote_uva(nro_lote) ON UPDATE CASCADE ON DELETE CASCADE |
| analisis_calidad | analisis_calidad_pkey | PRIMARY KEY | PRIMARY KEY (id_analisis) |
| auditoria_precio | auditoria_precio_cod_vino_fkey | FOREIGN KEY | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON UPDATE CASCADE ON DELETE RESTRICT |
| auditoria_precio | auditoria_precio_pkey | PRIMARY KEY | PRIMARY KEY (id_auditoria) |
| bodega | bodega_pkey | PRIMARY KEY | PRIMARY KEY (cuit) |
| bodega | uq_bodega_razon_social | UNIQUE | UNIQUE (razon_social) |
| cepa | ck_cepa_tipo | CHECK | CHECK (((tipo)::text = ANY ((ARRAY['tinta'::character varying, 'blanca'::character varying])::text[]))) |
| cepa | cepa_pkey | PRIMARY KEY | PRIMARY KEY (id_cepa) |
| cepa | uq_cepa_nombre | UNIQUE | UNIQUE (nombre) |
| cliente | ck_cliente_datos_tipo | CHECK | CHECK (((((tipo_cliente)::text = 'socio'::text) AND (zona_cobertura IS NULL) AND (nro_habilitacion IS NULL) AND (pais_destino_principal IS NULL)) OR (((tipo_cliente)::text = 'distribuidor'::text) AND (zona_cobertura IS NOT NULL) AND (nro_habilitacion IS NOT NULL) AND (pais_destino_principal IS NULL)) OR (((tipo_cliente)::text = 'exportador'::text) AND (pais_destino_principal IS NOT NULL) AND (zona_cobertura IS NULL) AND (nro_habilitacion IS NULL)))) |
| cliente | ck_cliente_descuento | CHECK | CHECK ((((descuento)::numeric >= (0)::numeric) AND ((descuento)::numeric <= (50)::numeric))) |
| cliente | ck_cliente_tipo | CHECK | CHECK (((tipo_cliente)::text = ANY ((ARRAY['socio'::character varying, 'distribuidor'::character varying, 'exportador'::character varying])::text[]))) |
| cliente | ck_cliente_tipo_doc | CHECK | CHECK (((tipo_doc)::text = ANY ((ARRAY['DNI'::character varying, 'CUIT'::character varying, 'PASAPORTE'::character varying])::text[]))) |
| cliente | cliente_cp_localidad_fkey | FOREIGN KEY | FOREIGN KEY (cp_localidad) REFERENCES localidad(codigo_postal) ON UPDATE CASCADE ON DELETE RESTRICT |
| cliente | cliente_pkey | PRIMARY KEY | PRIMARY KEY (id_cliente) |
| cliente | uq_cliente_documento | UNIQUE | UNIQUE (tipo_doc, nro_doc) |
| cliente | uq_cliente_habilitacion | UNIQUE | UNIQUE (nro_habilitacion) |
| composicion_vino | ck_composicion_porcentaje | CHECK | CHECK (((porcentaje >= 1) AND (porcentaje <= 100))) |
| composicion_vino | composicion_vino_cod_vino_fkey | FOREIGN KEY | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON UPDATE CASCADE ON DELETE CASCADE |
| composicion_vino | composicion_vino_id_cepa_fkey | FOREIGN KEY | FOREIGN KEY (id_cepa) REFERENCES cepa(id_cepa) ON UPDATE CASCADE ON DELETE RESTRICT |
| composicion_vino | composicion_vino_pkey | PRIMARY KEY | PRIMARY KEY (cod_vino, id_cepa) |
| comprobante | ck_comprobante_total | CHECK | CHECK (((total)::numeric = ((subtotal)::numeric - (descuento)::numeric))) |
| comprobante | comprobante_id_cliente_fkey | FOREIGN KEY | FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON UPDATE CASCADE ON DELETE RESTRICT |
| comprobante | comprobante_id_sala_fkey | FOREIGN KEY | FOREIGN KEY (id_sala) REFERENCES sala_venta(id_sala) ON UPDATE CASCADE ON DELETE RESTRICT |
| comprobante | comprobante_pkey | PRIMARY KEY | PRIMARY KEY (nro_comprobante) |
| empleado | ck_empleado_salario | CHECK | CHECK ((salario > (0)::numeric)) |
| empleado | empleado_id_sala_fkey | FOREIGN KEY | FOREIGN KEY (id_sala) REFERENCES sala_venta(id_sala) ON UPDATE CASCADE ON DELETE RESTRICT |
| empleado | empleado_pkey | PRIMARY KEY | PRIMARY KEY (cuit) |
| finca | ck_finca_superficie | CHECK | CHECK ((superficie_ha > (0)::numeric)) |
| finca | finca_pkey | PRIMARY KEY | PRIMARY KEY (id_finca) |
| ingreso | ingreso_codigo_transporte_fkey | FOREIGN KEY | FOREIGN KEY (codigo_transporte) REFERENCES transportista(codigo_transporte) ON UPDATE CASCADE ON DELETE RESTRICT |
| ingreso | ingreso_cuit_bodega_fkey | FOREIGN KEY | FOREIGN KEY (cuit_bodega) REFERENCES bodega(cuit) ON UPDATE CASCADE ON DELETE RESTRICT |
| ingreso | ingreso_pkey | PRIMARY KEY | PRIMARY KEY (codigo_ingreso) |
| localidad | localidad_pkey | PRIMARY KEY | PRIMARY KEY (codigo_postal) |
| lote_uva | ck_lote_fecha_campania | CHECK | CHECK ((EXTRACT(year FROM fecha_cosecha) = (campania)::numeric)) |
| lote_uva | ck_lote_kilos | CHECK | CHECK ((kilos_cosechados > (0)::numeric)) |
| lote_uva | lote_uva_cuit_bodega_destino_fkey | FOREIGN KEY | FOREIGN KEY (cuit_bodega_destino) REFERENCES bodega(cuit) ON UPDATE CASCADE ON DELETE RESTRICT |
| lote_uva | lote_uva_id_finca_nro_parcela_fkey | FOREIGN KEY | FOREIGN KEY (id_finca, nro_parcela) REFERENCES parcela(id_finca, nro_parcela) ON UPDATE CASCADE ON DELETE RESTRICT |
| lote_uva | lote_uva_pkey | PRIMARY KEY | PRIMARY KEY (nro_lote) |
| lote_uva | uq_lote_parcela_campania | UNIQUE | UNIQUE (id_finca, nro_parcela, campania) |
| maridaje | ck_maridaje_temperatura | CHECK | CHECK (((temperatura_servicio >= 2) AND (temperatura_servicio <= 25))) |
| maridaje | maridaje_pkey | PRIMARY KEY | PRIMARY KEY (id_maridaje) |
| maridaje | uq_maridaje_nombre | UNIQUE | UNIQUE (nombre) |
| parcela | ck_parcela_anio | CHECK | CHECK (((anio_plantacion >= 1900) AND (anio_plantacion <= 2100))) |
| parcela | ck_parcela_superficie | CHECK | CHECK ((superficie_ha > (0)::numeric)) |
| parcela | parcela_id_cepa_fkey | FOREIGN KEY | FOREIGN KEY (id_cepa) REFERENCES cepa(id_cepa) ON UPDATE CASCADE ON DELETE RESTRICT |
| parcela | parcela_id_finca_fkey | FOREIGN KEY | FOREIGN KEY (id_finca) REFERENCES finca(id_finca) ON UPDATE CASCADE ON DELETE CASCADE |
| parcela | parcela_pkey | PRIMARY KEY | PRIMARY KEY (id_finca, nro_parcela) |
| permiso_exportacion | ck_permiso_fechas | CHECK | CHECK ((fecha_vencimiento > fecha_emision)) |
| permiso_exportacion | permiso_exportacion_id_cliente_fkey | FOREIGN KEY | FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON UPDATE CASCADE ON DELETE CASCADE |
| permiso_exportacion | permiso_exportacion_pkey | PRIMARY KEY | PRIMARY KEY (codigo) |
| renglon_comprobante | ck_rc_cantidad | CHECK | CHECK ((cantidad > 0)) |
| renglon_comprobante | ck_rc_precio | CHECK | CHECK ((precio_unitario > (0)::numeric)) |
| renglon_comprobante | renglon_comprobante_cod_vino_fkey | FOREIGN KEY | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON UPDATE CASCADE ON DELETE RESTRICT |
| renglon_comprobante | renglon_comprobante_nro_comprobante_fkey | FOREIGN KEY | FOREIGN KEY (nro_comprobante) REFERENCES comprobante(nro_comprobante) ON UPDATE CASCADE ON DELETE CASCADE |
| renglon_comprobante | renglon_comprobante_pkey | PRIMARY KEY | PRIMARY KEY (nro_comprobante, cod_vino) |
| renglon_ingreso | ck_ri_cantidad | CHECK | CHECK ((cantidad > 0)) |
| renglon_ingreso | renglon_ingreso_cod_vino_fkey | FOREIGN KEY | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON UPDATE CASCADE ON DELETE RESTRICT |
| renglon_ingreso | renglon_ingreso_codigo_ingreso_fkey | FOREIGN KEY | FOREIGN KEY (codigo_ingreso) REFERENCES ingreso(codigo_ingreso) ON UPDATE CASCADE ON DELETE CASCADE |
| renglon_ingreso | renglon_ingreso_pkey | PRIMARY KEY | PRIMARY KEY (codigo_ingreso, cod_vino) |
| renglon_transferencia | ck_rt_cantidad | CHECK | CHECK ((cantidad > 0)) |
| renglon_transferencia | renglon_transferencia_cod_vino_fkey | FOREIGN KEY | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON UPDATE CASCADE ON DELETE RESTRICT |
| renglon_transferencia | renglon_transferencia_nro_transferencia_fkey | FOREIGN KEY | FOREIGN KEY (nro_transferencia) REFERENCES transferencia(nro_transferencia) ON UPDATE CASCADE ON DELETE CASCADE |
| renglon_transferencia | renglon_transferencia_pkey | PRIMARY KEY | PRIMARY KEY (nro_transferencia, cod_vino) |
| sala_venta | ck_sala_dia_cierre | CHECK | CHECK (((dia_cierre)::text = ANY ((ARRAY['lunes'::character varying, 'martes'::character varying, 'miercoles'::character varying, 'jueves'::character varying, 'viernes'::character varying, 'sabado'::character varying, 'domingo'::character varying])::text[]))) |
| sala_venta | sala_venta_cp_localidad_fkey | FOREIGN KEY | FOREIGN KEY (cp_localidad) REFERENCES localidad(codigo_postal) ON UPDATE CASCADE ON DELETE RESTRICT |
| sala_venta | sala_venta_pkey | PRIMARY KEY | PRIMARY KEY (id_sala) |
| stock_deposito | ck_stock_deposito_no_negativo | CHECK | CHECK ((cantidad >= 0)) |
| stock_deposito | stock_deposito_cod_vino_fkey | FOREIGN KEY | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON UPDATE CASCADE ON DELETE RESTRICT |
| stock_deposito | stock_deposito_pkey | PRIMARY KEY | PRIMARY KEY (cod_vino) |
| stock_sala | ck_stock_sala_no_negativo | CHECK | CHECK ((cantidad >= 0)) |
| stock_sala | stock_sala_cod_vino_fkey | FOREIGN KEY | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON UPDATE CASCADE ON DELETE RESTRICT |
| stock_sala | stock_sala_id_sala_fkey | FOREIGN KEY | FOREIGN KEY (id_sala) REFERENCES sala_venta(id_sala) ON UPDATE CASCADE ON DELETE RESTRICT |
| stock_sala | stock_sala_pkey | PRIMARY KEY | PRIMARY KEY (id_sala, cod_vino) |
| transferencia | transferencia_id_sala_fkey | FOREIGN KEY | FOREIGN KEY (id_sala) REFERENCES sala_venta(id_sala) ON UPDATE CASCADE ON DELETE RESTRICT |
| transferencia | transferencia_pkey | PRIMARY KEY | PRIMARY KEY (nro_transferencia) |
| transportista | ck_transportista_email | CHECK | CHECK (((email)::text ~~ '%_@_%._%'::text)) |
| transportista | transportista_pkey | PRIMARY KEY | PRIMARY KEY (codigo_transporte) |
| transportista | uq_transportista_cuit | UNIQUE | UNIQUE (cuit) |
| transportista_cubre_localidad | transportista_cubre_localidad_codigo_transporte_fkey | FOREIGN KEY | FOREIGN KEY (codigo_transporte) REFERENCES transportista(codigo_transporte) ON UPDATE CASCADE ON DELETE CASCADE |
| transportista_cubre_localidad | transportista_cubre_localidad_cp_localidad_fkey | FOREIGN KEY | FOREIGN KEY (cp_localidad) REFERENCES localidad(codigo_postal) ON UPDATE CASCADE ON DELETE CASCADE |
| transportista_cubre_localidad | transportista_cubre_localidad_pkey | PRIMARY KEY | PRIMARY KEY (codigo_transporte, cp_localidad) |
| vino | ck_vino_anada | CHECK | CHECK (((anada >= 1990) AND (anada <= 2100))) |
| vino | ck_vino_graduacion | CHECK | CHECK (((graduacion >= (5)::numeric) AND (graduacion <= (20)::numeric))) |
| vino | ck_vino_precio_positivo | CHECK | CHECK ((precio > (0)::numeric)) |
| vino | ck_vino_tipo | CHECK | CHECK (((tipo)::text = ANY ((ARRAY['tinto'::character varying, 'blanco'::character varying, 'rosado'::character varying, 'espumante'::character varying])::text[]))) |
| vino | ck_vino_volumen | CHECK | CHECK ((volumen_ml = ANY (ARRAY[187, 375, 750, 1500, 3000]))) |
| vino | vino_cuit_bodega_fkey | FOREIGN KEY | FOREIGN KEY (cuit_bodega) REFERENCES bodega(cuit) ON UPDATE CASCADE ON DELETE RESTRICT |
| vino | vino_pkey | PRIMARY KEY | PRIMARY KEY (cod_vino) |
| vino | uq_vino_nombre_anada_volumen | UNIQUE | UNIQUE (nombre, anada, volumen_ml) |
| vino_maridaje | vino_maridaje_cod_vino_fkey | FOREIGN KEY | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON UPDATE CASCADE ON DELETE CASCADE |
| vino_maridaje | vino_maridaje_id_maridaje_fkey | FOREIGN KEY | FOREIGN KEY (id_maridaje) REFERENCES maridaje(id_maridaje) ON UPDATE CASCADE ON DELETE RESTRICT |
| vino_maridaje | vino_maridaje_pkey | PRIMARY KEY | PRIMARY KEY (cod_vino, id_maridaje) |

## 2.5 Triggers

| Tabla | Trigger | Momento | Evento |
|---|---|---|---|
| cliente | trg_cliente_descuento | BEFORE | INSERT, UPDATE |
| composicion_vino | trg_composicion_suma_100 | AFTER | INSERT, DELETE, UPDATE |
| comprobante | trg_comprobante_importes | BEFORE | INSERT, UPDATE |
| ingreso | trg_ingreso_estado | BEFORE | UPDATE, INSERT |
| permiso_exportacion | trg_permiso_solo_exportador | BEFORE | UPDATE, INSERT |
| renglon_comprobante | trg_rc_descontar_stock | AFTER | INSERT |
| renglon_comprobante | trg_rc_proteger | BEFORE | UPDATE |
| renglon_comprobante | trg_rc_totales_del | AFTER | DELETE |
| renglon_comprobante | trg_rc_totales_ins | AFTER | INSERT |
| renglon_comprobante | trg_rc_totales_upd | AFTER | UPDATE |
| renglon_comprobante | trg_rc_validar_y_calcular | BEFORE | INSERT |
| renglon_ingreso | trg_renglon_ingreso_bloqueo | BEFORE | INSERT, UPDATE, DELETE |
| renglon_transferencia | trg_renglon_transf_bloqueo | BEFORE | UPDATE, INSERT, DELETE |
| transferencia | trg_transferencia_estado | BEFORE | UPDATE, INSERT |
| transferencia | trg_transferencia_fecha | BEFORE | INSERT, UPDATE |
| vino | trg_vino_auditoria_precio | AFTER | UPDATE |
| vino | trg_vino_composicion_100 | AFTER | INSERT |

## 2.6 Vistas

| Vista | Descripción |
|---|---|
| mv_ventas_por_vino (materializada) | Ranking de ventas por vino (refrescar tras cargas o al cerrar el día). |
| vw_documentos_pendientes | Ingresos y transferencias en confección o terminados. |
| vw_stock_total_vino | Stock por vino: depósito central, salas y total. |
| vw_ventas_mensuales_sala | Monto vendido y cantidad de comprobantes por sala y mes. |
