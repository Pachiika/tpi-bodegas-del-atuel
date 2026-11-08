-- =====================================================================
-- 006_vistas.sql  ·  Bodegas del Atuel
-- Vistas del sistema (3 comunes + 1 materializada).
-- =====================================================================
SET client_encoding = 'UTF8';   -- los archivos estan en UTF-8 (acentos bien tambien en Windows)

-- ---------------------------------------------------------------------
-- V1 · Stock total por vino = depósito central + suma de todas las salas.
-- Se agrega primero el stock de salas en una subconsulta para no
-- multiplicar filas al combinar depósito y salas.
-- La usan S6, S9, el endpoint GET /vinos/{cod} y el tablero.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_stock_total_vino AS
SELECT v.cod_vino,
       v.nombre,
       v.anada,
       v.volumen_ml,
       COALESCE(sd.cantidad, 0)                           AS stock_deposito,
       COALESCE(ss.stock_salas, 0)                        AS stock_en_salas,
       COALESCE(sd.cantidad, 0) + COALESCE(ss.stock_salas, 0) AS stock_total
  FROM vino v
  LEFT JOIN stock_deposito sd ON sd.cod_vino = v.cod_vino
  LEFT JOIN (SELECT cod_vino, SUM(cantidad) AS stock_salas
               FROM stock_sala
              GROUP BY cod_vino) ss ON ss.cod_vino = v.cod_vino;

COMMENT ON VIEW vw_stock_total_vino IS 'Stock por vino: depósito central, salas y total.';

-- ---------------------------------------------------------------------
-- V2 · Ventas mensuales por sala (cantidad de comprobantes y monto).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ventas_mensuales_sala AS
SELECT s.id_sala,
       l.nombre || ' - ' || s.calle || ' ' || s.numero AS sala,
       date_trunc('month', c.fecha)::date             AS mes,
       COUNT(*)                                        AS cantidad_comprobantes,
       SUM(c.total)                                    AS monto_total
  FROM comprobante c
  JOIN sala_venta s ON s.id_sala = c.id_sala
  JOIN localidad  l ON l.codigo_postal = s.cp_localidad
 GROUP BY s.id_sala, l.nombre, s.calle, s.numero, date_trunc('month', c.fecha);

COMMENT ON VIEW vw_ventas_mensuales_sala IS 'Monto vendido y cantidad de comprobantes por sala y mes.';

-- ---------------------------------------------------------------------
-- V3 · Documentos pendientes (ingresos y transferencias no procesados).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_documentos_pendientes AS
SELECT 'ingreso'::text     AS tipo_documento,
       i.codigo_ingreso    AS numero,
       i.estado,
       i.fecha,
       NULL::integer       AS id_sala,
       (SELECT COALESCE(SUM(cantidad), 0) FROM renglon_ingreso r
         WHERE r.codigo_ingreso = i.codigo_ingreso) AS botellas
  FROM ingreso i
 WHERE i.estado <> 'procesado'
UNION ALL
SELECT 'transferencia'::text,
       t.nro_transferencia,
       t.estado,
       t.fecha_confeccion,
       t.id_sala,
       (SELECT COALESCE(SUM(cantidad), 0) FROM renglon_transferencia r
         WHERE r.nro_transferencia = t.nro_transferencia)
  FROM transferencia t
 WHERE t.estado <> 'procesado';

COMMENT ON VIEW vw_documentos_pendientes IS 'Ingresos y transferencias en confección o terminados.';

-- ---------------------------------------------------------------------
-- V4 · (Materializada) Botellas vendidas e importe por vino.
-- Calcularla recorre los ~500.000 renglones, por eso se materializa:
-- el tablero la lee en milisegundos. Se actualiza con
--   REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_por_vino;
-- (CONCURRENTLY necesita el índice único que se crea abajo).
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_ventas_por_vino AS
SELECT v.cod_vino,
       v.nombre,
       v.tipo,
       v.anada,
       v.volumen_ml,
       COALESCE(SUM(rc.cantidad), 0) AS botellas_vendidas,
       COALESCE(SUM(rc.subtotal), 0) AS importe_vendido
  FROM vino v
  LEFT JOIN renglon_comprobante rc ON rc.cod_vino = v.cod_vino
 GROUP BY v.cod_vino, v.nombre, v.tipo, v.anada, v.volumen_ml;

CREATE UNIQUE INDEX uq_mv_ventas_por_vino ON mv_ventas_por_vino (cod_vino);

COMMENT ON MATERIALIZED VIEW mv_ventas_por_vino IS 'Ranking de ventas por vino (refrescar tras cargas o al cerrar el día).';
