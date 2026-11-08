-- =====================================================================
-- db/tests/db_tests.sql  ·  Bodegas del Atuel
-- Batería de pruebas de las reglas de negocio RN-01 a RN-15.
--
-- Cómo correrlo (sobre una base con las migraciones aplicadas, con o
-- sin la carga masiva):
--     psql -d bodegas -f db/tests/db_tests.sql
--
-- * Todo corre dentro de una transacción que termina en ROLLBACK: la base
--   queda igual que antes.
-- * pg_temp.debe_fallar(sql, regla, fragmento) ejecuta la sentencia en
--   una subtransacción y verifica que FALLE con un mensaje que contenga
--   el fragmento esperado. pg_temp.debe_funcionar(sql, regla) verifica que
--   NO falle.
-- * Al final se imprime un resumen. Si alguna prueba no da el resultado
--   esperado, el script termina con ERROR.
-- =====================================================================
\set ON_ERROR_STOP on
\echo '=== Pruebas de reglas de negocio - Bodegas del Atuel ==='

\set QUIET on
-- Cada SELECT pg_temp.xxx(...) termina en \gset en vez de ';' para que no
-- imprima nada (funciona igual en Windows y en Linux).
BEGIN;

CREATE TEMP TABLE resultado_prueba (
    n        SERIAL,
    regla    TEXT,
    caso     TEXT,
    esperado TEXT,
    ok       BOOLEAN,
    detalle  TEXT
) ON COMMIT DROP;

-- ---------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------
CREATE FUNCTION pg_temp.debe_fallar(p_sql TEXT, p_regla TEXT, p_fragmento TEXT, p_caso TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE p_sql;
        INSERT INTO resultado_prueba (regla, caso, esperado, ok, detalle)
        VALUES (p_regla, p_caso, 'falla', false, 'NO falló: ' || p_sql);
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO resultado_prueba (regla, caso, esperado, ok, detalle)
        VALUES (p_regla, p_caso, 'falla',
                position(lower(p_fragmento) IN lower(SQLSTATE || ': ' || SQLERRM)) > 0,
                SQLSTATE || ': ' || SQLERRM);
    END;
END;
$$;

CREATE FUNCTION pg_temp.debe_funcionar(p_sql TEXT, p_regla TEXT, p_caso TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE p_sql;
    INSERT INTO resultado_prueba (regla, caso, esperado, ok, detalle)
    VALUES (p_regla, p_caso, 'funciona', true, 'OK');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO resultado_prueba (regla, caso, esperado, ok, detalle)
    VALUES (p_regla, p_caso, 'funciona', false, SQLSTATE || ': ' || SQLERRM);
END;
$$;

CREATE FUNCTION pg_temp.verificar(p_condicion BOOLEAN, p_regla TEXT, p_caso TEXT, p_detalle TEXT)
RETURNS void LANGUAGE sql AS $$
    INSERT INTO resultado_prueba (regla, caso, esperado, ok, detalle)
    VALUES (p_regla, p_caso, 'condición', p_condicion, p_detalle);
$$;

-- ---------------------------------------------------------------------
-- Datos de prueba propios (identificadores altos para no chocar con la
-- carga masiva). Se descartan con el ROLLBACK final.
-- ---------------------------------------------------------------------
INSERT INTO localidad VALUES ('T9999', 'Localidad Test', 'Mendoza', 'Encargada Test');
INSERT INTO sala_venta (id_sala, calle, numero, dia_cierre, cp_localidad)
VALUES (90001, 'Calle Test', '100', 'lunes', 'T9999'),
       (90002, 'Calle Test', '200', 'martes', 'T9999');
INSERT INTO bodega VALUES ('30999999991', 'Bodega Test SA', 'Ruta 143 km 1');
INSERT INTO cepa (id_cepa, nombre, tipo) VALUES (90001, 'Cepa Test A', 'tinta'), (90002, 'Cepa Test B', 'tinta');

INSERT INTO vino (cod_vino, nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
VALUES (90001, 'Vino Test Reserva', 'tinto', 2021, 750, 14.00, 10000.00, '30999999991');
INSERT INTO composicion_vino VALUES (90001, 90001, 85), (90001, 90002, 15);

INSERT INTO cliente (id_cliente, nombre_o_razon_social, tipo_doc, nro_doc, direccion, cp_localidad, tipo_cliente,
                     zona_cobertura, nro_habilitacion, pais_destino_principal)
VALUES (90001, 'Socio Test',        'DNI',  '99000001',    'Dir 1', 'T9999', 'socio',        NULL,  NULL,         NULL),
       (90002, 'Distribuidor Test', 'CUIT', '30990000021', 'Dir 2', 'T9999', 'distribuidor', 'Sur', 'HAB-TEST-1', NULL),
       (90003, 'Exportador Test',   'CUIT', '30990000031', 'Dir 3', 'T9999', 'exportador',   NULL,  NULL,         'Brasil');

INSERT INTO stock_sala (id_sala, cod_vino, cantidad) VALUES (90001, 90001, 5);
INSERT INTO stock_deposito (cod_vino, cantidad) VALUES (90001, 100)
    ON CONFLICT (cod_vino) DO UPDATE SET cantidad = 100;

INSERT INTO transportista (codigo_transporte, razon_social, cuit, email, telefono, domicilio)
VALUES (90001, 'Transporte Test', '30999999992', 'test@transporte.com', '2604000000', 'Dir T');

INSERT INTO empleado VALUES ('20999999991', 'Empleado Test', '2015-03-01', 500000, 90001);

-- Validar ya mismo la composición del vino de prueba (es diferida).
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

-- =====================================================================
-- RN-01 · Precio único en vino y mayor que cero
-- =====================================================================
SELECT pg_temp.debe_fallar(
    $q$UPDATE vino SET precio = -500 WHERE cod_vino = 90001$q$,
    'RN-01', 'ck_vino_precio_positivo', 'Precio negativo rechazado por CHECK') \gset
SELECT pg_temp.debe_fallar(
    $q$UPDATE vino SET precio = 0 WHERE cod_vino = 90001$q$,
    'RN-01', 'ck_vino_precio_positivo', 'Precio cero rechazado por CHECK') \gset

-- =====================================================================
-- RN-02 · Una sala pertenece a una sola localidad existente
-- =====================================================================
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO sala_venta (calle, numero, dia_cierre, cp_localidad) VALUES ('X', '1', 'lunes', 'NOEXISTE')$q$,
    'RN-02', '23503', 'Sala con localidad inexistente rechazada por FK') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO sala_venta (calle, numero, dia_cierre, cp_localidad) VALUES ('X', '1', 'lunes', NULL)$q$,
    'RN-02', 'null', 'Sala sin localidad rechazada por NOT NULL') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO localidad VALUES ('T9999', 'Otra', 'Mendoza', 'Otro encargado')$q$,
    'RN-02', 'localidad_pkey', 'No hay dos filas (dos encargados) para la misma localidad') \gset

-- =====================================================================
-- RN-03 · Cada empleado trabaja en una sola sala (obligatoria)
-- =====================================================================
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO empleado VALUES ('20999999992', 'Sin sala', '2020-01-01', 400000, NULL)$q$,
    'RN-03', 'null', 'Empleado sin sala rechazado por NOT NULL') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO empleado VALUES ('20999999993', 'Sala falsa', '2020-01-01', 400000, 123456789)$q$,
    'RN-03', '23503', 'Empleado con sala inexistente rechazado por FK') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO empleado VALUES ('209999', 'CUIT corto', '2020-01-01', 400000, 90001)$q$,
    'RN-03', 'cuit_dom', 'CUIT mal formado rechazado por el DOMAIN cuit_dom') \gset

-- =====================================================================
-- RN-04 · Una parcela tiene una sola cepa y se cosecha una vez por campaña
-- =====================================================================
INSERT INTO finca (id_finca, nombre, superficie_ha, departamento, provincia) VALUES (90001, 'Finca Test', 50, 'San Rafael', 'Mendoza');
INSERT INTO parcela VALUES (90001, 1, 5, 2010, 90001);
SELECT pg_temp.debe_funcionar(
    $q$INSERT INTO lote_uva (id_finca, nro_parcela, campania, fecha_cosecha, kilos_cosechados, cuit_bodega_destino)
       VALUES (90001, 1, 2026, '2026-03-10', 1500, '30999999991')$q$,
    'RN-04', 'Primera cosecha de la parcela en la campaña 2026') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO lote_uva (id_finca, nro_parcela, campania, fecha_cosecha, kilos_cosechados, cuit_bodega_destino)
       VALUES (90001, 1, 2026, '2026-03-20', 1200, '30999999991')$q$,
    'RN-04', 'uq_lote_parcela_campania', 'Segunda cosecha en la misma campaña rechazada por UNIQUE') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO parcela VALUES (90001, 2, 5, 2010, NULL)$q$,
    'RN-04', 'null', 'Parcela sin cepa rechazada por NOT NULL') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO lote_uva (id_finca, nro_parcela, campania, fecha_cosecha, kilos_cosechados, cuit_bodega_destino)
       VALUES (90001, 1, 2025, '2026-03-10', 900, '30999999991')$q$,
    'RN-04', 'ck_lote_fecha_campania', 'Fecha de cosecha fuera de su campaña (CHECK entre columnas)') \gset

-- =====================================================================
-- RN-05 · Los porcentajes de corte suman 100 (constraint trigger diferido)
-- =====================================================================
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO vino (cod_vino, nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
       VALUES (90002, 'Vino Corte Malo', 'tinto', 2022, 750, 13.5, 9000, '30999999991');
       INSERT INTO composicion_vino VALUES (90002, 90001, 60), (90002, 90002, 30);
       SET CONSTRAINTS ALL IMMEDIATE$q$,
    'RN-05', 'deben sumar 100', 'Corte 60 % + 30 % rechazado al validar (suma 90)') \gset
SET CONSTRAINTS ALL DEFERRED;
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO vino (cod_vino, nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
       VALUES (90003, 'Vino Sin Corte', 'tinto', 2022, 750, 13.5, 9000, '30999999991');
       SET CONSTRAINTS ALL IMMEDIATE$q$,
    'RN-05', 'deben sumar 100', 'Vino sin composición rechazado al validar') \gset
SET CONSTRAINTS ALL DEFERRED;
SELECT pg_temp.debe_funcionar(
    $q$INSERT INTO vino (cod_vino, nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
       VALUES (90004, 'Vino Corte Bueno', 'tinto', 2022, 750, 13.5, 9000, '30999999991');
       INSERT INTO composicion_vino VALUES (90004, 90001, 70), (90004, 90002, 30);
       SET CONSTRAINTS ALL IMMEDIATE$q$,
    'RN-05', 'Corte 70 % + 30 % aceptado (vino y cepas en varias sentencias)') \gset
SET CONSTRAINTS ALL DEFERRED;

-- =====================================================================
-- RN-06 · Descuento según tipo de cliente
-- =====================================================================
SELECT pg_temp.verificar(
    (SELECT descuento FROM cliente WHERE id_cliente = 90001) = 10
    AND (SELECT descuento FROM cliente WHERE id_cliente = 90002) = 20
    AND (SELECT descuento FROM cliente WHERE id_cliente = 90003) = 30,
    'RN-06', 'El trigger asigna 10 % / 20 % / 30 % según el tipo',
    'socio=' || (SELECT descuento FROM cliente WHERE id_cliente = 90001)
    || ' distribuidor=' || (SELECT descuento FROM cliente WHERE id_cliente = 90002)
    || ' exportador=' || (SELECT descuento FROM cliente WHERE id_cliente = 90003)) \gset
SELECT pg_temp.debe_fallar(
    $q$UPDATE cliente SET descuento = 80 WHERE id_cliente = 90001$q$,
    'RN-06', 'ck_cliente_descuento', 'Descuento fuera de rango rechazado por CHECK') \gset
SELECT pg_temp.debe_fallar(
    $q$UPDATE cliente SET zona_cobertura = 'Norte', nro_habilitacion = 'HAB-X' WHERE id_cliente = 90001$q$,
    'RN-06', 'ck_cliente_datos_tipo', 'Un socio no puede tener datos de distribuidor (CHECK entre columnas)') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO cliente (nombre_o_razon_social, tipo_doc, nro_doc, direccion, cp_localidad, tipo_cliente)
       VALUES ('Distribuidor sin zona', 'CUIT', '30990000099', 'Dir', 'T9999', 'distribuidor')$q$,
    'RN-06', 'ck_cliente_datos_tipo', 'Un distribuidor tiene que tener zona y habilitacion') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO cliente (nombre_o_razon_social, tipo_doc, nro_doc, direccion, cp_localidad, tipo_cliente)
       VALUES ('Tipo raro', 'DNI', '99000099', 'Dir', 'T9999', 'mayorista')$q$,
    'RN-06', '23514', 'Tipo de cliente que no existe rechazado por CHECK') \gset

-- =====================================================================
-- RN-07 · Permisos de exportación con vencimiento posterior a emisión
-- =====================================================================
SELECT pg_temp.debe_funcionar(
    $q$INSERT INTO permiso_exportacion VALUES ('PERM-T-1', 90003, '2025-01-01', '2026-01-01');
       INSERT INTO permiso_exportacion VALUES ('PERM-T-2', 90003, '2025-06-01', '2026-06-01')$q$,
    'RN-07', 'Un exportador con varios permisos') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO permiso_exportacion VALUES ('PERM-T-3', 90003, '2026-01-01', '2025-01-01')$q$,
    'RN-07', 'ck_permiso_fechas', 'Vencimiento anterior a la emisión rechazado (CHECK entre columnas)') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO permiso_exportacion VALUES ('PERM-T-4', 90001, '2025-01-01', '2026-01-01')$q$,
    'RN-07', 'no es exportador', 'Un socio no puede tener permisos de exportación (trigger)') \gset

-- =====================================================================
-- RN-08 · El total del comprobante lo calcula la base
-- =====================================================================
INSERT INTO comprobante (nro_comprobante, id_cliente, id_sala, subtotal, descuento, total)
VALUES (900001, 90002, 90001, 999, 999, 0);   -- importes "a mano": se ignoran
INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
VALUES (900001, 90001, 2, 1, 0, 1);            -- precio/descuento/subtotal "a mano": se ignoran
SELECT pg_temp.verificar(
    (SELECT subtotal = 20000 AND descuento = 4000 AND total = 16000
       FROM comprobante WHERE nro_comprobante = 900001),
    'RN-08', 'Total = 2 x 10000 con 20 % de distribuidor = 16000 (calculado por triggers)',
    (SELECT format('subtotal=%s descuento=%s total=%s', subtotal, descuento, total)
       FROM comprobante WHERE nro_comprobante = 900001)) \gset
SELECT pg_temp.verificar(
    (SELECT precio_unitario = 10000 AND descuento_aplicado = 20 AND subtotal = 16000
       FROM renglon_comprobante WHERE nro_comprobante = 900001),
    'RN-08', 'El renglón toma precio del vino y descuento del cliente',
    (SELECT format('precio=%s desc=%s subtotal=%s', precio_unitario, descuento_aplicado, subtotal)
       FROM renglon_comprobante WHERE nro_comprobante = 900001)) \gset
UPDATE comprobante SET total = 1, subtotal = 1, descuento = 0 WHERE nro_comprobante = 900001;
SELECT pg_temp.verificar(
    (SELECT total FROM comprobante WHERE nro_comprobante = 900001) = 16000,
    'RN-08', 'Un UPDATE manual del total se recalcula (no se puede cargar a mano)',
    'total=' || (SELECT total FROM comprobante WHERE nro_comprobante = 900001)) \gset
SELECT pg_temp.debe_fallar(
    $q$UPDATE renglon_comprobante SET cantidad = 1 WHERE nro_comprobante = 900001$q$,
    'RN-08', 'RN-08', 'No se puede cambiar la cantidad de un renglón ya vendido') \gset

-- =====================================================================
-- RN-09 · No se vende más que el stock de la sala; stock nunca negativo
-- =====================================================================
SELECT pg_temp.verificar(
    fn_stock_sala(90001, 90001) = 3,
    'RN-09', 'La venta de 2 botellas descontó el stock (5 -> 3)',
    'stock=' || fn_stock_sala(90001, 90001)) \gset
INSERT INTO comprobante (nro_comprobante, id_cliente, id_sala) VALUES (900002, 90001, 90001);
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad) VALUES (900002, 90001, 9999)$q$,
    'RN-09', 'stock insuficiente', 'Vender 9999 botellas con stock 3 rechazado por trigger BEFORE INSERT') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO comprobante (nro_comprobante, id_cliente, id_sala) VALUES (900003, 90001, 90002);
       INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad) VALUES (900003, 90001, 1)$q$,
    'RN-09', 'stock insuficiente', 'Vender en una sala sin fila de stock rechazado') \gset
SELECT pg_temp.debe_fallar(
    $q$UPDATE stock_sala SET cantidad = -1 WHERE id_sala = 90001 AND cod_vino = 90001$q$,
    'RN-09', 'ck_stock_sala_no_negativo', 'Stock negativo rechazado por CHECK') \gset
SELECT pg_temp.verificar(
    fn_stock_sala(90001, 90001) = 3,
    'RN-09', 'Las ventas rechazadas no dejaron cambios a medias',
    'stock=' || fn_stock_sala(90001, 90001)) \gset

-- =====================================================================
-- RN-10 · Circuito de estados de ingresos
-- =====================================================================
INSERT INTO ingreso (codigo_ingreso, codigo_transporte, cuit_bodega) VALUES (900001, 90001, '30999999991');
SELECT pg_temp.verificar(
    (SELECT estado = 'en_confeccion' AND fecha::date = CURRENT_DATE FROM ingreso WHERE codigo_ingreso = 900001),
    'RN-10', 'Un ingreso nuevo nace en_confeccion con fecha actual (DEFAULT)', 'OK') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO ingreso (codigo_ingreso, estado, codigo_transporte, cuit_bodega) VALUES (900002, 'procesado', 90001, '30999999991')$q$,
    'RN-10', 'en_confeccion', 'No se puede crear un ingreso directamente procesado') \gset
SELECT pg_temp.debe_fallar(
    $q$UPDATE ingreso SET estado = 'terminado' WHERE codigo_ingreso = 900001$q$,
    'RN-10', 'no tiene renglones', 'No se puede terminar un ingreso sin renglones') \gset
INSERT INTO renglon_ingreso VALUES (900001, 90001, 120);
SELECT pg_temp.debe_fallar(
    $q$CALL sp_procesar_ingreso(900001)$q$,
    'RN-10', 'solo un ingreso terminado', 'No se puede procesar un ingreso en confección') \gset
UPDATE ingreso SET estado = 'terminado' WHERE codigo_ingreso = 900001;
SELECT pg_temp.debe_fallar(
    $q$UPDATE ingreso SET estado = 'procesado' WHERE codigo_ingreso = 900001$q$,
    'RN-10', 'sp_procesar_ingreso', 'No se puede pasar a procesado con un UPDATE directo') \gset
SELECT pg_temp.debe_funcionar(
    $q$CALL sp_procesar_ingreso(900001)$q$,
    'RN-10', 'El procedimiento procesa el ingreso terminado') \gset
SELECT pg_temp.verificar(
    (SELECT cantidad FROM stock_deposito WHERE cod_vino = 90001) = 220
    AND (SELECT estado FROM ingreso WHERE codigo_ingreso = 900001) = 'procesado',
    'RN-10', 'El depósito sumó 120 botellas (100 -> 220) y el ingreso quedó procesado',
    'deposito=' || (SELECT cantidad FROM stock_deposito WHERE cod_vino = 90001)) \gset
SELECT pg_temp.debe_fallar(
    $q$UPDATE ingreso SET estado = 'en_confeccion' WHERE codigo_ingreso = 900001$q$,
    'RN-10', 'transición de estado inválida', 'Un ingreso procesado no retrocede de estado') \gset
SELECT pg_temp.debe_fallar(
    $q$CALL sp_procesar_ingreso(900001)$q$,
    'RN-10', 'solo un ingreso terminado', 'Un ingreso no se procesa dos veces') \gset

-- =====================================================================
-- RN-11 · Transferencias: estados, fecha actual inmodificable y stock
-- =====================================================================
INSERT INTO transferencia (nro_transferencia, id_sala, fecha_confeccion)
VALUES (900001, 90002, '2000-01-01');          -- fecha "a mano": se fuerza la actual
SELECT pg_temp.verificar(
    (SELECT fecha_confeccion::date = CURRENT_DATE FROM transferencia WHERE nro_transferencia = 900001),
    'RN-11', 'La fecha de confección se fuerza a la fecha actual',
    (SELECT fecha_confeccion::text FROM transferencia WHERE nro_transferencia = 900001)) \gset
SELECT pg_temp.debe_fallar(
    $q$UPDATE transferencia SET fecha_confeccion = '2020-01-01' WHERE nro_transferencia = 900001$q$,
    'RN-11', 'no se puede modificar', 'La fecha de confección no se puede modificar') \gset
INSERT INTO renglon_transferencia VALUES (900001, 90001, 500);   -- más de lo que hay (220)
UPDATE transferencia SET estado = 'terminado' WHERE nro_transferencia = 900001;
SELECT pg_temp.debe_fallar(
    $q$CALL sp_procesar_transferencia(900001)$q$,
    'RN-11', 'stock insuficiente en el depósito', 'Procesar sin stock suficiente en el depósito falla') \gset
SELECT pg_temp.verificar(
    (SELECT cantidad FROM stock_deposito WHERE cod_vino = 90001) = 220
    AND fn_stock_sala(90002, 90001) = 0
    AND (SELECT estado FROM transferencia WHERE nro_transferencia = 900001) = 'terminado',
    'RN-11', 'La transferencia fallida no dejó cambios a medias',
    'deposito=' || (SELECT cantidad FROM stock_deposito WHERE cod_vino = 90001)
    || ' sala=' || fn_stock_sala(90002, 90001)) \gset
INSERT INTO transferencia (nro_transferencia, id_sala) VALUES (900002, 90002);
INSERT INTO renglon_transferencia VALUES (900002, 90001, 50);
UPDATE transferencia SET estado = 'terminado' WHERE nro_transferencia = 900002;
SELECT pg_temp.debe_funcionar(
    $q$CALL sp_procesar_transferencia(900002)$q$,
    'RN-11', 'Procesar una transferencia con stock suficiente') \gset
SELECT pg_temp.verificar(
    (SELECT cantidad FROM stock_deposito WHERE cod_vino = 90001) = 170
    AND fn_stock_sala(90002, 90001) = 50,
    'RN-11', 'Se descontaron 50 del depósito (220 -> 170) y se sumaron a la sala (0 -> 50)',
    'deposito=' || (SELECT cantidad FROM stock_deposito WHERE cod_vino = 90001)
    || ' sala=' || fn_stock_sala(90002, 90001)) \gset
SELECT pg_temp.debe_fallar(
    $q$UPDATE transferencia SET estado = 'terminado' WHERE nro_transferencia = 900002$q$,
    'RN-11', 'transición de estado inválida', 'Una transferencia procesada no retrocede') \gset

-- =====================================================================
-- RN-12 · Sin cambios en renglones de documentos que no están en confección
-- =====================================================================
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO renglon_ingreso VALUES (900001, 90004, 10)$q$,
    'RN-12', 'no admite', 'No se agregan renglones a un ingreso procesado') \gset
SELECT pg_temp.debe_fallar(
    $q$UPDATE renglon_transferencia SET cantidad = 10 WHERE nro_transferencia = 900001$q$,
    'RN-12', 'no admite', 'No se modifican renglones de una transferencia terminada') \gset
SELECT pg_temp.debe_fallar(
    $q$DELETE FROM renglon_transferencia WHERE nro_transferencia = 900002$q$,
    'RN-12', 'no admite', 'No se quitan renglones de una transferencia procesada') \gset
INSERT INTO transferencia (nro_transferencia, id_sala) VALUES (900003, 90001);
SELECT pg_temp.debe_funcionar(
    $q$INSERT INTO renglon_transferencia VALUES (900003, 90001, 5);
       UPDATE renglon_transferencia SET cantidad = 6 WHERE nro_transferencia = 900003;
       DELETE FROM renglon_transferencia WHERE nro_transferencia = 900003$q$,
    'RN-12', 'En confección sí se pueden agregar, modificar y quitar renglones') \gset

-- =====================================================================
-- RN-13 · Auditoría de cambios de precio
-- =====================================================================
UPDATE vino SET precio = 11500 WHERE cod_vino = 90001;
SELECT pg_temp.verificar(
    EXISTS (SELECT 1 FROM auditoria_precio
             WHERE cod_vino = 90001 AND precio_anterior = 10000 AND precio_nuevo = 11500
               AND usuario = session_user),
    'RN-13', 'El cambio de precio 10000 -> 11500 quedó auditado con usuario y fecha', 'OK') \gset
UPDATE vino SET nombre = 'Vino Test Reserva' WHERE cod_vino = 90001;   -- sin cambio de precio
SELECT pg_temp.verificar(
    (SELECT count(*) FROM auditoria_precio WHERE cod_vino = 90001) = 1,
    'RN-13', 'Un UPDATE que no cambia el precio no genera auditoría', 'OK') \gset

-- =====================================================================
-- RN-14 · No se borran transportistas, bodegas ni vinos con movimientos
-- =====================================================================
SELECT pg_temp.debe_fallar(
    $q$DELETE FROM transportista WHERE codigo_transporte = 90001$q$,
    'RN-14', '_fkey', 'Transportista con ingresos no se puede borrar (RESTRICT)') \gset
SELECT pg_temp.debe_fallar(
    $q$DELETE FROM bodega WHERE cuit = '30999999991'$q$,
    'RN-14', '_fkey', 'Bodega con vinos e ingresos no se puede borrar (RESTRICT)') \gset
SELECT pg_temp.debe_fallar(
    $q$DELETE FROM vino WHERE cod_vino = 90001$q$,
    'RN-14', '_fkey', 'Vino con ventas y stock no se puede borrar (RESTRICT)') \gset
SELECT pg_temp.debe_funcionar(
    $q$DELETE FROM vino WHERE cod_vino = 90004; SET CONSTRAINTS ALL IMMEDIATE$q$,
    'RN-14', 'Un vino sin movimientos sí se puede borrar (su composición se borra en cascada)') \gset
SET CONSTRAINTS ALL DEFERRED;

-- =====================================================================
-- RN-15 · Cantidades, superficies, kilos y precios positivos; graduación 5-20
-- =====================================================================
SELECT pg_temp.debe_fallar(
    $q$UPDATE vino SET graduacion = 25 WHERE cod_vino = 90001$q$,
    'RN-15', 'ck_vino_graduacion', 'Graduación 25 rechazada') \gset
SELECT pg_temp.debe_fallar(
    $q$UPDATE vino SET graduacion = 4.5 WHERE cod_vino = 90001$q$,
    'RN-15', 'ck_vino_graduacion', 'Graduación 4,5 rechazada') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO finca (nombre, superficie_ha, departamento, provincia) VALUES ('Finca cero', 0, 'San Rafael', 'Mendoza')$q$,
    'RN-15', 'ck_finca_superficie', 'Superficie 0 rechazada') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO lote_uva (id_finca, nro_parcela, campania, fecha_cosecha, kilos_cosechados, cuit_bodega_destino)
       VALUES (90001, 1, 2024, '2024-03-01', -10, '30999999991')$q$,
    'RN-15', 'ck_lote_kilos', 'Kilos negativos rechazados') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO renglon_transferencia VALUES (900003, 90001, 0)$q$,
    'RN-15', 'ck_rt_cantidad', 'Cantidad 0 en un renglón rechazada') \gset

-- =====================================================================
-- Roles: la API (app_rw) no es propietaria y no tiene permisos de sobra
-- =====================================================================
-- Un ingreso terminado para intentar "procesarlo" sin el procedimiento.
INSERT INTO ingreso (codigo_ingreso, codigo_transporte, cuit_bodega) VALUES (900003, 90001, '30999999991');
INSERT INTO renglon_ingreso VALUES (900003, 90001, 10);
UPDATE ingreso SET estado = 'terminado' WHERE codigo_ingreso = 900003;

-- La tabla temporal de resultados la tiene que poder escribir app_rw.
GRANT ALL ON resultado_prueba TO app_rw;
GRANT ALL ON SEQUENCE resultado_prueba_n_seq TO app_rw;
SET LOCAL ROLE app_rw;
SELECT pg_temp.debe_fallar(
    $q$DROP TABLE vino$q$,
    'Roles', '42501', 'app_rw no puede borrar tablas (no es propietario)') \gset
SELECT pg_temp.debe_fallar(
    $q$INSERT INTO auditoria_precio (cod_vino, precio_anterior, precio_nuevo) VALUES (90001, 1, 2)$q$,
    'Roles', '42501', 'app_rw no puede falsificar la auditoría') \gset
SELECT pg_temp.debe_fallar(
    $q$UPDATE ingreso SET estado = 'procesado' WHERE codigo_ingreso = 900003$q$,
    'Roles', 'sp_procesar_ingreso', 'app_rw no puede pasar un ingreso a procesado sin el procedimiento') \gset
SELECT pg_temp.debe_funcionar(
    $q$CALL sp_procesar_ingreso(900003)$q$,
    'Roles', 'app_rw sí puede procesarlo llamando al procedimiento (SECURITY DEFINER)') \gset
SELECT pg_temp.debe_funcionar(
    $q$UPDATE vino SET precio = 12000 WHERE cod_vino = 90001$q$,
    'Roles', 'app_rw puede cambiar un precio y la auditoría se registra igual (trigger SECURITY DEFINER)') \gset
RESET ROLE;
SELECT pg_temp.verificar(
    EXISTS (SELECT 1 FROM auditoria_precio WHERE cod_vino = 90001 AND precio_nuevo = 12000 AND usuario = session_user),
    'Roles', 'La auditoría del cambio hecho por app_rw quedó registrada', 'OK') \gset

-- =====================================================================
-- Resumen
-- =====================================================================
\echo ''
\echo '--- Resultado de cada prueba ---'
SELECT n, regla, CASE WHEN ok THEN 'OK' ELSE 'FALLÓ' END AS resultado, esperado, caso, left(detalle, 140) AS detalle
  FROM resultado_prueba ORDER BY n;

SELECT regla,
       count(*)                       AS casos,
       count(*) FILTER (WHERE ok)     AS ok,
       count(*) FILTER (WHERE NOT ok) AS fallidos
  FROM resultado_prueba GROUP BY regla ORDER BY regla;

DO $$
DECLARE v_mal INTEGER;
BEGIN
    SELECT count(*) INTO v_mal FROM resultado_prueba WHERE NOT ok;
    IF v_mal > 0 THEN
        RAISE EXCEPTION '% prueba(s) no dieron el resultado esperado', v_mal;
    END IF;
    RAISE NOTICE 'Todas las pruebas dieron el resultado esperado (% casos).',
                 (SELECT count(*) FROM resultado_prueba);
END
$$;

ROLLBACK;
\echo '=== Fin de las pruebas (ROLLBACK: la base quedó sin cambios) ==='
