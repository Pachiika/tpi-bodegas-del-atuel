-- =====================================================================
-- docs/rendimiento/medir_consultas.sql · Etapa 4 · Índices y rendimiento
--
-- Mide con EXPLAIN (ANALYZE, BUFFERS) las consultas candidatas.
-- Procedimiento usado para el informe (docs/05_indices_rendimiento.md):
--   1. Base cargada SIN 008_indices.sql  -> ANALYZE -> este script  (antes)
--   2. psql -f db/migrations/008_indices.sql -> ANALYZE -> este script (después)
-- Cada consulta se ejecuta dos veces y se registra la segunda (caché
-- caliente), para comparar el efecto del índice y no el de la lectura
-- desde disco.
--     psql -d bodegas -f docs/rendimiento/medir_consultas.sql > planes.txt
-- =====================================================================
\set sala   1
\set bodega '''Bodega Salto de las Rosas S.A.'''
ANALYZE;

\echo '################ Q1 = S3: clientes por tipo que compraron en una sala la última semana'
SELECT count(*) FROM comprobante WHERE id_sala = :sala AND fecha >= CURRENT_DATE - INTERVAL '7 days' \g /dev/null
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT t.tipo AS tipo_cliente, count(DISTINCT c.id_cliente) AS clientes
  FROM unnest(enum_range(NULL::tipo_cliente)) AS t(tipo)
  LEFT JOIN cliente cl ON cl.tipo_cliente = t.tipo
  LEFT JOIN comprobante c ON c.id_cliente = cl.id_cliente
                         AND c.id_sala = :sala
                         AND c.fecha >= CURRENT_DATE - INTERVAL '7 days'
 GROUP BY t.tipo;

\echo '################ Q2 = S8: monto de ventas por sala en el último trimestre'
SELECT count(*) FROM comprobante WHERE fecha >= CURRENT_DATE - INTERVAL '3 months' \g /dev/null
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT s.id_sala, SUM(c.total) AS monto_total
  FROM comprobante c
  JOIN sala_venta s ON s.id_sala = c.id_sala
 WHERE c.fecha >= CURRENT_DATE - INTERVAL '3 months'
 GROUP BY s.id_sala
 ORDER BY monto_total DESC;

\echo '################ Q3 = S12 a): clientes que compraron todos los vinos de una bodega (NOT EXISTS)'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT cl.id_cliente
  FROM cliente cl
 WHERE NOT EXISTS (
         SELECT 1 FROM vino v JOIN bodega b ON b.cuit = v.cuit_bodega
          WHERE b.razon_social = :bodega
            AND NOT EXISTS (
                  SELECT 1
                    FROM comprobante c
                    JOIN renglon_comprobante rc ON rc.nro_comprobante = c.nro_comprobante
                   WHERE c.id_cliente = cl.id_cliente
                     AND rc.cod_vino = v.cod_vino));

\echo '################ Q4 = S12 b): clientes que nunca compraron vino tinto (anti-join)'
SELECT 1 \g /dev/null
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT count(*)
  FROM cliente cl
 WHERE NOT EXISTS (
         SELECT 1
           FROM comprobante c
           JOIN renglon_comprobante rc ON rc.nro_comprobante = c.nro_comprobante
           JOIN vino v ON v.cod_vino = rc.cod_vino
          WHERE c.id_cliente = cl.id_cliente AND v.tipo = 'tinto');

\echo '################ Q5 = Historial de compras de un cliente (endpoint GET /clientes/{id})'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT c.nro_comprobante, c.fecha, c.total
  FROM comprobante c
 WHERE c.id_cliente = 1638
 ORDER BY c.fecha DESC;

\echo '################ Q6 = Transferencias pendientes de una sala (pantalla de transferencias)'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT nro_transferencia, fecha_confeccion, estado
  FROM transferencia
 WHERE id_sala = 4 AND estado <> 'procesado'
 ORDER BY fecha_confeccion;
