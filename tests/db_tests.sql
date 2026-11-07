-- =====================================================================
-- BODEGAS DEL ATUEL - SCRIPT DE PRUEBAS (tests/db_tests.sql)
-- =====================================================================
-- Este script prueba las reglas de negocio (RN-01 a RN-15).
-- Las transacciones con fallos esperados usan ROLLBACK o bloques de excepción.
-- =====================================================================

\echo '--- INICIANDO BATERÍA DE PRUEBAS DE LA BASE DE DATOS ---'

-- ----------------------------------------------------------------5
-- PRUEBA 1: RN-01 / RN-15 - Precio y Graduación de Vino (Debe FALLAR)
-- ----------------------------------------------------------------5
\echo 'Prueba 1: Intentar insertar un vino con precio negativo (Debe fallar por CHECK)'
BEGIN;
INSERT INTO vino (nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
VALUES ('Vino Mal Ejemplo', 'tinto', 2022, 750, 14.00, -500.00, '30712345671');
-- Si llega acá por error, hace rollback
ROLLBACK;


-- ----------------------------------------------------------------5
-- PRUEBA 2: RN-04 - Parcela y Campaña única (Debe FALLAR si se repite)
-- ----------------------------------------------------------------5
\echo 'Prueba 2: Cosechar la misma parcela dos veces en la misma campaña (Debe fallar)'
BEGIN;
-- Suponiendo que ya existe el lote para la finca 1, parcela 1, campaña 2026:
INSERT INTO lote_uva (id_finca, nro_parcela, campania, fecha_cosecha, kilos_cosechados, cuit_bodega_destino)
VALUES (1, 1, 2026, '2026-03-10', 1500.00, '30712345671');
-- Intentar duplicar la misma parcela en la misma campaña:
INSERT INTO lote_uva (id_finca, nro_parcela, campania, fecha_cosecha, kilos_cosechados, cuit_bodega_destino)
VALUES (1, 1, 2026, '2026-03-12', 1200.00, '30712345671');
ROLLBACK;


-- ----------------------------------------------------------------5
-- PRUEBA 3: RN-09 - Stock insuficiente en venta (Debe FALLAR)
-- ----------------------------------------------------------------5
\echo 'Prueba 3: Vender más botellas de las que existen en la sala (Debe fallar por trigger RN-09)'
BEGIN;
-- Creamos un comprobante de prueba (asumiendo cliente 1 y sala 1)
INSERT INTO comprobante (fecha, id_cliente, id_sala, subtotal, descuento, total)
VALUES (NOW(), 1, 1, 0, 0, 0);

-- Intentar insertar un renglón pidiendo 9999 botellas (disparará el trigger de stock insuficiente)
INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
VALUES (1, 1, 9999, 1000.00, 0, 9999000.00);
ROLLBACK;


-- ----------------------------------------------------------------5
-- PRUEBA 4: RN-12 - Modificar renglón de transferencia procesada (Debe FALLAR)
-- ----------------------------------------------------------------5
\echo 'Prueba 4: Modificar renglones de un documento que ya no está en confección (Debe fallar por RN-12)'
BEGIN;
-- Insertamos una transferencia de prueba y la pasamos a procesado (o simulamos estado bloqueado)
-- El trigger bloqueará inserciones/actualizaciones/borrados si el estado != 'en_confeccion'
UPDATE transferencia SET estado = 'procesado' WHERE nro_transferencia = 1;

-- Intentar borrar o alterar un renglón de esa transferencia:
DELETE FROM renglon_transferencia WHERE nro_transferencia = 1;
ROLLBACK;


\echo '--- FIN DE LAS PRUEBAS ---'