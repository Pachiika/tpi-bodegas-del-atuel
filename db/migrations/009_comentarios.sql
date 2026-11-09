SET client_encoding = 'UTF8';

-- 009_comentarios.sql
-- Descripción de cada columna (COMMENT ON COLUMN).
-- Alimenta la columna "Descripción" del diccionario de datos (docs/02_diccionario_datos.md).

-- analisis_calidad
COMMENT ON COLUMN analisis_calidad.id_analisis IS 'Identificador del análisis de calidad.';
COMMENT ON COLUMN analisis_calidad.nro_lote IS 'Lote de uva analizado. Un lote puede tener varios análisis.';
COMMENT ON COLUMN analisis_calidad.fecha IS 'Fecha en que se practicó el análisis.';
COMMENT ON COLUMN analisis_calidad.grado_brix IS 'Grado Brix (contenido de azúcar) de la muestra.';
COMMENT ON COLUMN analisis_calidad.ph IS 'pH de la muestra.';
COMMENT ON COLUMN analisis_calidad.acidez_total IS 'Acidez total de la muestra, en g/L.';

-- auditoria_precio
COMMENT ON COLUMN auditoria_precio.id_auditoria IS 'Identificador del registro de auditoría.';
COMMENT ON COLUMN auditoria_precio.cod_vino IS 'Vino cuyo precio cambió.';
COMMENT ON COLUMN auditoria_precio.precio_anterior IS 'Precio antes del cambio.';
COMMENT ON COLUMN auditoria_precio.precio_nuevo IS 'Precio después del cambio.';
COMMENT ON COLUMN auditoria_precio.fecha_hora IS 'Fecha y hora del cambio. La completa el trigger de auditoría (RN-13).';
COMMENT ON COLUMN auditoria_precio.usuario IS 'Usuario de la base que hizo el cambio. Lo completa el trigger de auditoría (RN-13).';

-- bodega
COMMENT ON COLUMN bodega.cuit IS 'CUIT de la bodega (11 dígitos). Clave primaria.';
COMMENT ON COLUMN bodega.razon_social IS 'Razón social de la bodega.';
COMMENT ON COLUMN bodega.domicilio IS 'Domicilio de la bodega.';

-- cepa
COMMENT ON COLUMN cepa.id_cepa IS 'Identificador de la cepa.';
COMMENT ON COLUMN cepa.nombre IS 'Nombre de la cepa (por ejemplo Malbec).';
COMMENT ON COLUMN cepa.tipo IS 'Tipo de cepa: tinta o blanca.';

-- cliente (tabla única para los tres tipos de cliente)
COMMENT ON COLUMN cliente.id_cliente IS 'Identificador del cliente.';
COMMENT ON COLUMN cliente.nombre_o_razon_social IS 'Apellido y nombre, o razón social si es una empresa.';
COMMENT ON COLUMN cliente.tipo_doc IS 'Tipo de documento del cliente.';
COMMENT ON COLUMN cliente.nro_doc IS 'Número de documento del cliente.';
COMMENT ON COLUMN cliente.direccion IS 'Dirección del cliente.';
COMMENT ON COLUMN cliente.cp_localidad IS 'Localidad del cliente, por código postal.';
COMMENT ON COLUMN cliente.fecha_alta IS 'Fecha de alta del cliente.';
COMMENT ON COLUMN cliente.tipo_cliente IS 'Tipo de cliente: socio del club, distribuidor o exportador. Define el descuento.';
COMMENT ON COLUMN cliente.descuento IS 'Porcentaje de descuento según el tipo de cliente: 10 % socio, 20 % distribuidor, 30 % exportador (RN-06).';
COMMENT ON COLUMN cliente.zona_cobertura IS 'Solo distribuidores: zona de cobertura.';
COMMENT ON COLUMN cliente.nro_habilitacion IS 'Solo distribuidores: número de habilitación.';
COMMENT ON COLUMN cliente.pais_destino_principal IS 'Solo exportadores: país de destino principal.';

-- composicion_vino
COMMENT ON COLUMN composicion_vino.cod_vino IS 'Vino que se compone.';
COMMENT ON COLUMN composicion_vino.id_cepa IS 'Cepa que forma parte del vino.';
COMMENT ON COLUMN composicion_vino.porcentaje IS 'Porcentaje de corte de la cepa en el vino. La suma por vino debe ser 100 (RN-05).';

-- comprobante
COMMENT ON COLUMN comprobante.nro_comprobante IS 'Número del comprobante de venta.';
COMMENT ON COLUMN comprobante.fecha IS 'Fecha y hora de la venta.';
COMMENT ON COLUMN comprobante.id_cliente IS 'Cliente que compró.';
COMMENT ON COLUMN comprobante.id_sala IS 'Sala de venta donde se realizó la venta.';
COMMENT ON COLUMN comprobante.subtotal IS 'Importe de los renglones antes del descuento. Lo calcula la base, no se carga a mano (RN-08).';
COMMENT ON COLUMN comprobante.descuento IS 'Importe del descuento aplicado. Lo calcula la base (RN-08).';
COMMENT ON COLUMN comprobante.total IS 'Total del comprobante. Lo calcula la base, no se carga a mano (RN-08).';

-- empleado
COMMENT ON COLUMN empleado.cuit IS 'CUIT del empleado (11 dígitos). Clave primaria.';
COMMENT ON COLUMN empleado.nombre IS 'Nombre del empleado.';
COMMENT ON COLUMN empleado.fecha_ingreso IS 'Fecha de ingreso laboral. Es la base para calcular la antigüedad.';
COMMENT ON COLUMN empleado.salario IS 'Salario del empleado.';
COMMENT ON COLUMN empleado.id_sala IS 'Sala donde trabaja. Cada empleado trabaja en una sola sala (RN-03).';

-- finca
COMMENT ON COLUMN finca.id_finca IS 'Identificador de la finca.';
COMMENT ON COLUMN finca.nombre IS 'Nombre de la finca.';
COMMENT ON COLUMN finca.superficie_ha IS 'Superficie total de la finca, en hectáreas.';
COMMENT ON COLUMN finca.departamento IS 'Departamento donde se ubica la finca.';
COMMENT ON COLUMN finca.provincia IS 'Provincia donde se ubica la finca.';

-- ingreso
COMMENT ON COLUMN ingreso.codigo_ingreso IS 'Código del ingreso al depósito central.';
COMMENT ON COLUMN ingreso.fecha IS 'Fecha del ingreso.';
COMMENT ON COLUMN ingreso.estado IS 'Estado: en_confeccion, terminado o procesado. Solo avanza en ese orden (RN-10).';
COMMENT ON COLUMN ingreso.codigo_transporte IS 'Transportista que hizo el traslado.';
COMMENT ON COLUMN ingreso.cuit_bodega IS 'Bodega de origen de los vinos.';

-- localidad
COMMENT ON COLUMN localidad.codigo_postal IS 'Código postal. Clave natural de la localidad.';
COMMENT ON COLUMN localidad.nombre IS 'Nombre de la localidad.';
COMMENT ON COLUMN localidad.provincia IS 'Provincia de la localidad.';
COMMENT ON COLUMN localidad.encargado_regional IS 'Encargado regional (responsable comercial). Es único por localidad, por eso está acá y no en la sala (RN-02, 3FN).';

-- lote_uva
COMMENT ON COLUMN lote_uva.nro_lote IS 'Número del lote de uva.';
COMMENT ON COLUMN lote_uva.id_finca IS 'Finca de la parcela cosechada. Junto con nro_parcela identifica la parcela.';
COMMENT ON COLUMN lote_uva.nro_parcela IS 'Número de la parcela cosechada dentro de la finca.';
COMMENT ON COLUMN lote_uva.campania IS 'Año de la campaña (cosecha). Una parcela se cosecha a lo sumo una vez por campaña (RN-04).';
COMMENT ON COLUMN lote_uva.fecha_cosecha IS 'Fecha de cosecha.';
COMMENT ON COLUMN lote_uva.kilos_cosechados IS 'Kilos de uva cosechados. Siempre positivo (RN-15).';
COMMENT ON COLUMN lote_uva.cuit_bodega_destino IS 'Bodega a la que se entregó el lote.';

-- maridaje
COMMENT ON COLUMN maridaje.id_maridaje IS 'Identificador del maridaje.';
COMMENT ON COLUMN maridaje.nombre IS 'Nombre del maridaje (por ejemplo carnes rojas).';
COMMENT ON COLUMN maridaje.temperatura_servicio IS 'Temperatura de servicio sugerida, en °C.';

-- parcela
COMMENT ON COLUMN parcela.id_finca IS 'Finca a la que pertenece la parcela. Junto con nro_parcela forma la clave (entidad débil).';
COMMENT ON COLUMN parcela.nro_parcela IS 'Número de la parcela dentro de la finca.';
COMMENT ON COLUMN parcela.superficie_ha IS 'Superficie de la parcela, en hectáreas.';
COMMENT ON COLUMN parcela.anio_plantacion IS 'Año de plantación.';
COMMENT ON COLUMN parcela.id_cepa IS 'Cepa plantada. Cada parcela tiene una sola cepa (RN-04).';

-- permiso_exportacion
COMMENT ON COLUMN permiso_exportacion.codigo IS 'Código del permiso de exportación.';
COMMENT ON COLUMN permiso_exportacion.id_cliente IS 'Exportador titular del permiso. Un exportador puede tener varios (RN-07).';
COMMENT ON COLUMN permiso_exportacion.fecha_emision IS 'Fecha de emisión del permiso.';
COMMENT ON COLUMN permiso_exportacion.fecha_vencimiento IS 'Fecha de vencimiento. Debe ser posterior a la emisión (RN-07).';

-- renglon_comprobante
COMMENT ON COLUMN renglon_comprobante.nro_comprobante IS 'Comprobante al que pertenece el renglón.';
COMMENT ON COLUMN renglon_comprobante.cod_vino IS 'Vino vendido en el renglón.';
COMMENT ON COLUMN renglon_comprobante.cantidad IS 'Botellas vendidas. Positiva y no mayor al stock de la sala (RN-09, RN-15).';
COMMENT ON COLUMN renglon_comprobante.precio_unitario IS 'Precio unitario del vino al momento de la venta.';
COMMENT ON COLUMN renglon_comprobante.descuento_aplicado IS 'Porcentaje de descuento del renglón, según el tipo de cliente (RN-06).';
COMMENT ON COLUMN renglon_comprobante.subtotal IS 'Importe del renglón. Lo calcula la base (RN-08).';

-- renglon_ingreso
COMMENT ON COLUMN renglon_ingreso.codigo_ingreso IS 'Ingreso al que pertenece el renglón.';
COMMENT ON COLUMN renglon_ingreso.cod_vino IS 'Vino que ingresa.';
COMMENT ON COLUMN renglon_ingreso.cantidad IS 'Cantidad de botellas que ingresan. Positiva (RN-15).';

-- renglon_transferencia
COMMENT ON COLUMN renglon_transferencia.nro_transferencia IS 'Transferencia a la que pertenece el renglón.';
COMMENT ON COLUMN renglon_transferencia.cod_vino IS 'Vino solicitado.';
COMMENT ON COLUMN renglon_transferencia.cantidad IS 'Cantidad de botellas solicitadas. Positiva (RN-15).';

-- sala_venta
COMMENT ON COLUMN sala_venta.id_sala IS 'Identificador de la sala de venta.';
COMMENT ON COLUMN sala_venta.calle IS 'Calle de la dirección de la sala.';
COMMENT ON COLUMN sala_venta.numero IS 'Número de la dirección de la sala.';
COMMENT ON COLUMN sala_venta.dia_cierre IS 'Día de cierre semanal de la sala.';
COMMENT ON COLUMN sala_venta.cp_localidad IS 'Localidad donde está la sala. Cada sala está en una sola localidad (RN-02).';

-- stock_deposito
COMMENT ON COLUMN stock_deposito.cod_vino IS 'Vino almacenado en el depósito central.';
COMMENT ON COLUMN stock_deposito.cantidad IS 'Botellas en el depósito central. Nunca negativa (RN-09).';

-- stock_sala
COMMENT ON COLUMN stock_sala.id_sala IS 'Sala que tiene el stock.';
COMMENT ON COLUMN stock_sala.cod_vino IS 'Vino en stock.';
COMMENT ON COLUMN stock_sala.cantidad IS 'Botellas en la sala. Nunca negativa (RN-09).';

-- transferencia
COMMENT ON COLUMN transferencia.nro_transferencia IS 'Número de solicitud de la transferencia.';
COMMENT ON COLUMN transferencia.id_sala IS 'Sala que solicita los vinos al depósito central.';
COMMENT ON COLUMN transferencia.fecha_confeccion IS 'Fecha de confección. La fija un trigger con la fecha actual y no se puede modificar (RN-11).';
COMMENT ON COLUMN transferencia.estado IS 'Estado: en_confeccion, terminado o procesado. Solo avanza en ese orden (RN-11).';

-- transportista
COMMENT ON COLUMN transportista.codigo_transporte IS 'Código de la empresa de transporte.';
COMMENT ON COLUMN transportista.razon_social IS 'Razón social del transportista.';
COMMENT ON COLUMN transportista.cuit IS 'CUIT del transportista (11 dígitos).';
COMMENT ON COLUMN transportista.email IS 'Correo electrónico del transportista.';
COMMENT ON COLUMN transportista.telefono IS 'Teléfono del transportista.';
COMMENT ON COLUMN transportista.domicilio IS 'Domicilio del transportista.';

-- transportista_cubre_localidad
COMMENT ON COLUMN transportista_cubre_localidad.codigo_transporte IS 'Transportista que presta el servicio.';
COMMENT ON COLUMN transportista_cubre_localidad.cp_localidad IS 'Localidad alcanzada por el servicio del transportista.';

-- vino
COMMENT ON COLUMN vino.cod_vino IS 'Código del vino.';
COMMENT ON COLUMN vino.nombre IS 'Nombre comercial del vino.';
COMMENT ON COLUMN vino.tipo IS 'Tipo de vino: tinto, blanco, rosado o espumante.';
COMMENT ON COLUMN vino.anada IS 'Añada (año de la cosecha del vino).';
COMMENT ON COLUMN vino.volumen_ml IS 'Presentación en ml (por ejemplo 375, 750 o 1500).';
COMMENT ON COLUMN vino.graduacion IS 'Graduación alcohólica, entre 5 y 20 (RN-15).';
COMMENT ON COLUMN vino.precio IS 'Precio de venta, igual para todas las salas y mayor que cero (RN-01). Sus cambios se auditan (RN-13).';
COMMENT ON COLUMN vino.cuit_bodega IS 'Bodega que elabora el vino.';

-- vino_maridaje
COMMENT ON COLUMN vino_maridaje.cod_vino IS 'Vino recomendado.';
COMMENT ON COLUMN vino_maridaje.id_maridaje IS 'Maridaje recomendado para el vino.';
