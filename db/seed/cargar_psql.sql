-- =====================================================================
-- db/seed/cargar_psql.sql · Alternativa a 'seed.py cargar' usando solo psql
-- Carga los CSV de db/seed/datos/ con \copy, en el orden de las FK.
-- Ejecutar DESDE LA RAÍZ del repositorio, con el rol propietario:
--     python db/seed/seed.py generar
--     psql "$DATABASE_URL_OWNER" -f db/seed/cargar_psql.sql
-- (Mismo manejo de triggers que seed.py: ver comentario en seed.py.)
-- =====================================================================
\set ON_ERROR_STOP on
\timing on
BEGIN;

-- 1. Deshabilitar triggers propios (los internos de FK siguen activos)
ALTER TABLE localidad DISABLE TRIGGER USER;
ALTER TABLE departamento DISABLE TRIGGER USER;
ALTER TABLE cepa DISABLE TRIGGER USER;
ALTER TABLE maridaje DISABLE TRIGGER USER;
ALTER TABLE bodega DISABLE TRIGGER USER;
ALTER TABLE transportista DISABLE TRIGGER USER;
ALTER TABLE transportista_localidad DISABLE TRIGGER USER;
ALTER TABLE sala_venta DISABLE TRIGGER USER;
ALTER TABLE empleado DISABLE TRIGGER USER;
ALTER TABLE finca DISABLE TRIGGER USER;
ALTER TABLE parcela DISABLE TRIGGER USER;
ALTER TABLE lote_uva DISABLE TRIGGER USER;
ALTER TABLE analisis_calidad DISABLE TRIGGER USER;
ALTER TABLE vino DISABLE TRIGGER USER;
ALTER TABLE composicion_vino DISABLE TRIGGER USER;
ALTER TABLE vino_maridaje DISABLE TRIGGER USER;
ALTER TABLE cliente DISABLE TRIGGER USER;
ALTER TABLE distribuidor DISABLE TRIGGER USER;
ALTER TABLE exportador DISABLE TRIGGER USER;
ALTER TABLE permiso_exportacion DISABLE TRIGGER USER;
ALTER TABLE comprobante DISABLE TRIGGER USER;
ALTER TABLE renglon_comprobante DISABLE TRIGGER USER;
ALTER TABLE ingreso DISABLE TRIGGER USER;
ALTER TABLE renglon_ingreso DISABLE TRIGGER USER;
ALTER TABLE transferencia DISABLE TRIGGER USER;
ALTER TABLE renglon_transferencia DISABLE TRIGGER USER;
ALTER TABLE stock_deposito DISABLE TRIGGER USER;
ALTER TABLE stock_sala DISABLE TRIGGER USER;
ALTER TABLE auditoria_precio DISABLE TRIGGER USER;

-- 2. Cargar en orden de dependencias
\echo 'Cargando localidad'
\copy localidad FROM 'db/seed/datos/localidad.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando departamento'
\copy departamento FROM 'db/seed/datos/departamento.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando cepa'
\copy cepa FROM 'db/seed/datos/cepa.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando maridaje'
\copy maridaje FROM 'db/seed/datos/maridaje.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando bodega'
\copy bodega FROM 'db/seed/datos/bodega.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando transportista'
\copy transportista FROM 'db/seed/datos/transportista.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando transportista_localidad'
\copy transportista_localidad FROM 'db/seed/datos/transportista_localidad.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando sala_venta'
\copy sala_venta FROM 'db/seed/datos/sala_venta.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando empleado'
\copy empleado FROM 'db/seed/datos/empleado.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando finca'
\copy finca FROM 'db/seed/datos/finca.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando parcela'
\copy parcela FROM 'db/seed/datos/parcela.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando lote_uva'
\copy lote_uva FROM 'db/seed/datos/lote_uva.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando analisis_calidad'
\copy analisis_calidad FROM 'db/seed/datos/analisis_calidad.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando vino'
\copy vino FROM 'db/seed/datos/vino.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando composicion_vino'
\copy composicion_vino FROM 'db/seed/datos/composicion_vino.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando vino_maridaje'
\copy vino_maridaje FROM 'db/seed/datos/vino_maridaje.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando cliente'
\copy cliente FROM 'db/seed/datos/cliente.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando distribuidor'
\copy distribuidor FROM 'db/seed/datos/distribuidor.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando exportador'
\copy exportador FROM 'db/seed/datos/exportador.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando permiso_exportacion'
\copy permiso_exportacion FROM 'db/seed/datos/permiso_exportacion.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando comprobante'
\copy comprobante FROM 'db/seed/datos/comprobante.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando renglon_comprobante'
\copy renglon_comprobante FROM 'db/seed/datos/renglon_comprobante.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando ingreso'
\copy ingreso FROM 'db/seed/datos/ingreso.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando renglon_ingreso'
\copy renglon_ingreso FROM 'db/seed/datos/renglon_ingreso.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando transferencia'
\copy transferencia FROM 'db/seed/datos/transferencia.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando renglon_transferencia'
\copy renglon_transferencia FROM 'db/seed/datos/renglon_transferencia.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando stock_deposito'
\copy stock_deposito FROM 'db/seed/datos/stock_deposito.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando stock_sala'
\copy stock_sala FROM 'db/seed/datos/stock_sala.csv' WITH (FORMAT csv, HEADER true)
\echo 'Cargando auditoria_precio'
\copy auditoria_precio FROM 'db/seed/datos/auditoria_precio.csv' WITH (FORMAT csv, HEADER true)

-- 3. Rehabilitar triggers
ALTER TABLE localidad ENABLE TRIGGER USER;
ALTER TABLE departamento ENABLE TRIGGER USER;
ALTER TABLE cepa ENABLE TRIGGER USER;
ALTER TABLE maridaje ENABLE TRIGGER USER;
ALTER TABLE bodega ENABLE TRIGGER USER;
ALTER TABLE transportista ENABLE TRIGGER USER;
ALTER TABLE transportista_localidad ENABLE TRIGGER USER;
ALTER TABLE sala_venta ENABLE TRIGGER USER;
ALTER TABLE empleado ENABLE TRIGGER USER;
ALTER TABLE finca ENABLE TRIGGER USER;
ALTER TABLE parcela ENABLE TRIGGER USER;
ALTER TABLE lote_uva ENABLE TRIGGER USER;
ALTER TABLE analisis_calidad ENABLE TRIGGER USER;
ALTER TABLE vino ENABLE TRIGGER USER;
ALTER TABLE composicion_vino ENABLE TRIGGER USER;
ALTER TABLE vino_maridaje ENABLE TRIGGER USER;
ALTER TABLE cliente ENABLE TRIGGER USER;
ALTER TABLE distribuidor ENABLE TRIGGER USER;
ALTER TABLE exportador ENABLE TRIGGER USER;
ALTER TABLE permiso_exportacion ENABLE TRIGGER USER;
ALTER TABLE comprobante ENABLE TRIGGER USER;
ALTER TABLE renglon_comprobante ENABLE TRIGGER USER;
ALTER TABLE ingreso ENABLE TRIGGER USER;
ALTER TABLE renglon_ingreso ENABLE TRIGGER USER;
ALTER TABLE transferencia ENABLE TRIGGER USER;
ALTER TABLE renglon_transferencia ENABLE TRIGGER USER;
ALTER TABLE stock_deposito ENABLE TRIGGER USER;
ALTER TABLE stock_sala ENABLE TRIGGER USER;
ALTER TABLE auditoria_precio ENABLE TRIGGER USER;

-- 4. Ajustar las secuencias IDENTITY al máximo cargado
SELECT setval(pg_get_serial_sequence('sala_venta', 'id_sala'), (SELECT COALESCE(MAX(id_sala), 0) + 1 FROM sala_venta), false);
SELECT setval(pg_get_serial_sequence('cepa', 'id_cepa'), (SELECT COALESCE(MAX(id_cepa), 0) + 1 FROM cepa), false);
SELECT setval(pg_get_serial_sequence('departamento', 'id_departamento'), (SELECT COALESCE(MAX(id_departamento), 0) + 1 FROM departamento), false);
SELECT setval(pg_get_serial_sequence('finca', 'id_finca'), (SELECT COALESCE(MAX(id_finca), 0) + 1 FROM finca), false);
SELECT setval(pg_get_serial_sequence('lote_uva', 'nro_lote'), (SELECT COALESCE(MAX(nro_lote), 0) + 1 FROM lote_uva), false);
SELECT setval(pg_get_serial_sequence('analisis_calidad', 'id_analisis'), (SELECT COALESCE(MAX(id_analisis), 0) + 1 FROM analisis_calidad), false);
SELECT setval(pg_get_serial_sequence('vino', 'cod_vino'), (SELECT COALESCE(MAX(cod_vino), 0) + 1 FROM vino), false);
SELECT setval(pg_get_serial_sequence('maridaje', 'id_maridaje'), (SELECT COALESCE(MAX(id_maridaje), 0) + 1 FROM maridaje), false);
SELECT setval(pg_get_serial_sequence('cliente', 'id_cliente'), (SELECT COALESCE(MAX(id_cliente), 0) + 1 FROM cliente), false);
SELECT setval(pg_get_serial_sequence('comprobante', 'nro_comprobante'), (SELECT COALESCE(MAX(nro_comprobante), 0) + 1 FROM comprobante), false);
SELECT setval(pg_get_serial_sequence('transportista', 'codigo_transporte'), (SELECT COALESCE(MAX(codigo_transporte), 0) + 1 FROM transportista), false);
SELECT setval(pg_get_serial_sequence('ingreso', 'codigo_ingreso'), (SELECT COALESCE(MAX(codigo_ingreso), 0) + 1 FROM ingreso), false);
SELECT setval(pg_get_serial_sequence('transferencia', 'nro_transferencia'), (SELECT COALESCE(MAX(nro_transferencia), 0) + 1 FROM transferencia), false);
SELECT setval(pg_get_serial_sequence('auditoria_precio', 'id_auditoria'), (SELECT COALESCE(MAX(id_auditoria), 0) + 1 FROM auditoria_precio), false);

REFRESH MATERIALIZED VIEW mv_ventas_por_vino;
COMMIT;
\timing off
ANALYZE;
\echo 'Consultas de control (todas deben dar 0):'
\i db/seed/control.sql
