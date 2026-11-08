-- Costo de escritura de los indices: se cargan los mismos 517.840 renglones
-- en una tabla sin indices secundarios y en otra con el indice INCLUDE.
-- Ejecutar desde la raiz del repo:  psql -d bodegas -f docs/rendimiento/costo_escritura.sql
\timing on
DROP TABLE IF EXISTS pr_sin_idx, pr_con_idx;
CREATE TABLE pr_sin_idx (LIKE renglon_comprobante INCLUDING DEFAULTS);
ALTER TABLE pr_sin_idx ADD PRIMARY KEY (nro_comprobante, cod_vino);
CREATE TABLE pr_con_idx (LIKE pr_sin_idx INCLUDING ALL);
CREATE INDEX ON pr_con_idx (cod_vino) INCLUDE (cantidad);
CREATE INDEX ON pr_con_idx (nro_comprobante, subtotal);
\echo '--- COPY sin indices secundarios'
\copy pr_sin_idx FROM 'db/seed/datos/renglon_comprobante.csv' WITH (FORMAT csv, HEADER true)
\echo '--- COPY con 2 indices secundarios'
\copy pr_con_idx FROM 'db/seed/datos/renglon_comprobante.csv' WITH (FORMAT csv, HEADER true)
\echo '--- UPDATE de 50.000 filas en cada tabla'
UPDATE pr_sin_idx SET cantidad = cantidad + 1 WHERE nro_comprobante <= 15000;
UPDATE pr_con_idx SET cantidad = cantidad + 1 WHERE nro_comprobante <= 15000;
\timing off
SELECT relname, pg_size_pretty(pg_total_relation_size(oid)) AS tamanio_total,
       pg_size_pretty(pg_indexes_size(oid)) AS tamanio_indices
FROM pg_class WHERE relname IN ('pr_sin_idx','pr_con_idx');
DROP TABLE pr_sin_idx, pr_con_idx;
