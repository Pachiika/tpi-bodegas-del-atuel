-- 1) Indice DESCARTADO: cliente(tipo_cliente). Solo 3 valores y muy desbalanceados
--    (socio ~75 %). Para 'socio' el planificador lo ignora (Seq Scan) y las consultas
--    por distribuidor/exportador ya se resuelven por las tablas de subtipo (PK id_cliente).
BEGIN;
CREATE INDEX idx_prueba_cliente_tipo ON cliente (tipo_cliente);
ANALYZE cliente;
SELECT tipo_cliente, count(*) FROM cliente GROUP BY 1 ORDER BY 2 DESC;
EXPLAIN (ANALYZE, COSTS OFF) SELECT * FROM cliente WHERE tipo_cliente = 'socio';
SELECT pg_size_pretty(pg_relation_size('idx_prueba_cliente_tipo')) AS tamanio_indice_descartado;
ROLLBACK;

-- 2) Indice que el planificador NO usa: idx_vino_nombre_lower (expresion, text_pattern_ops).
--    a) Con comodin al principio un B-tree no sirve: Seq Scan.
EXPLAIN (ANALYZE, COSTS OFF) SELECT cod_vino, nombre FROM vino WHERE lower(nombre) LIKE '%reserva%';
--    b) Sin lower() la expresion no coincide con la del indice: Seq Scan.
EXPLAIN (ANALYZE, COSTS OFF) SELECT cod_vino, nombre FROM vino WHERE nombre LIKE 'Malbec%';
--    c) Con lower() y prefijo si lo usa:
EXPLAIN (ANALYZE, COSTS OFF) SELECT cod_vino, nombre FROM vino WHERE lower(nombre) LIKE 'malbec%';

-- 3) S12 b) (ver planes_despues.txt, Q4) tampoco usa idx_rc_vino_incl_cantidad: la mitad
--    de los vinos son tintos, hay que leer ~50 % de los renglones y Hash Join + Seq Scan
--    es mas barato que 255.000 accesos por indice.
