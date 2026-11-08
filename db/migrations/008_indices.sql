-- =====================================================================
-- 008_indices.sql  ·  Bodegas del Atuel
-- Etapa 4: índices diseñados a partir de los planes de ejecución.
-- Evidencia (EXPLAIN ANALYZE antes / después, costo de escritura e
-- índices descartados) en docs/05_indices_rendimiento.md.
--
-- PostgreSQL crea índices automáticamente solo para PRIMARY KEY y
-- UNIQUE. Las claves foráneas NO se indexan solas.
-- =====================================================================
SET client_encoding = 'UTF8';   -- los archivos estan en UTF-8 (acentos bien tambien en Windows)

-- ---------------------------------------------------------------------
-- 1. Índice sobre clave foránea: comprobante(id_cliente)
-- Sin él, "las compras de un cliente" obliga a recorrer los 150.000
-- comprobantes. Lo usan S12 a) y b) (NOT EXISTS correlacionado por
-- cliente), D4/D6 (clientes sin compras), el historial del cliente en la
-- API y la verificación de la FK al borrar un cliente.
-- Medido: S12 a) pasó de ~70 s a ~0,5 s (ver informe).
-- ---------------------------------------------------------------------
CREATE INDEX idx_comprobante_cliente
    ON comprobante (id_cliente);

-- ---------------------------------------------------------------------
-- 2. Índice COMPUESTO: comprobante(id_sala, fecha)
-- Ventas de una sala en un rango de fechas (S3, tablero, reportes por
-- sala). Orden de columnas: primero id_sala porque se filtra por
-- IGUALDAD y después fecha porque se filtra por RANGO; así el índice
-- recorre un único tramo contiguo. Con el orden inverso (fecha, id_sala)
-- habría que leer todas las salas del rango y descartar las demás.
-- También sirve para la FK comprobante.id_sala (prefijo izquierdo).
-- ---------------------------------------------------------------------
CREATE INDEX idx_comprobante_sala_fecha
    ON comprobante (id_sala, fecha);

-- ---------------------------------------------------------------------
-- 3. Índice sobre clave foránea con INCLUDE (cubriente):
--    renglon_comprobante(cod_vino) INCLUDE (cantidad)
-- La PK es (nro_comprobante, cod_vino): sirve para buscar por
-- comprobante, pero NO por vino. Este índice cubre la FK hacia vino
-- (borrar un vino, RN-14), las búsquedas "renglones de un vino" y, al
-- incluir cantidad, permite contar botellas de un vino con un
-- Index Only Scan, sin visitar la tabla.
-- ---------------------------------------------------------------------
CREATE INDEX idx_rc_vino_incl_cantidad
    ON renglon_comprobante (cod_vino) INCLUDE (cantidad);

-- ---------------------------------------------------------------------
-- 4. Índice BRIN: comprobante(fecha)
-- Los comprobantes se insertan en orden cronológico, así que la fecha
-- está físicamente correlacionada con el orden de la tabla. Un BRIN
-- guarda solo el mínimo y el máximo de cada bloque de páginas: ocupa unos
-- pocos KB (contra varios MB de un B-tree) y permite saltear los bloques
-- fuera del rango en consultas por período (S8: último trimestre).
-- ---------------------------------------------------------------------
CREATE INDEX idx_comprobante_fecha_brin
    ON comprobante USING brin (fecha) WITH (pages_per_range = 32);

-- ---------------------------------------------------------------------
-- 5. Índice PARCIAL: transferencias pendientes
-- Solo indexa las transferencias que todavía no se procesaron (una
-- fracción mínima de la tabla). Es chico, barato de mantener y es
-- exactamente lo que consultan la pantalla de transferencias, S5 y la
-- vista vw_documentos_pendientes.
-- ---------------------------------------------------------------------
CREATE INDEX idx_transferencia_pendientes
    ON transferencia (id_sala, fecha_confeccion)
    WHERE estado <> 'procesado';

-- ---------------------------------------------------------------------
-- 6. Índices sobre otras claves foráneas usadas en joins y borrados
-- ---------------------------------------------------------------------
CREATE INDEX idx_empleado_sala            ON empleado (id_sala);
CREATE INDEX idx_vino_bodega              ON vino (cuit_bodega);
CREATE INDEX idx_ingreso_transportista    ON ingreso (codigo_transporte, fecha);
CREATE INDEX idx_renglon_transf_vino      ON renglon_transferencia (cod_vino);
CREATE INDEX idx_renglon_ingreso_vino     ON renglon_ingreso (cod_vino);
CREATE INDEX idx_stock_sala_vino          ON stock_sala (cod_vino);
CREATE INDEX idx_lote_bodega              ON lote_uva (cuit_bodega_destino);

-- ---------------------------------------------------------------------
-- 7. Índice de EXPRESIÓN: búsqueda de vinos por nombre sin distinguir
--    mayúsculas (filtro "q" del catálogo: lower(nombre) LIKE 'malbec%').
-- text_pattern_ops permite usarlo con LIKE 'prefijo%'.
-- Nota del informe: con 600 vinos el planificador suele preferir un Seq
-- Scan (leer 8 páginas es más barato que el índice); es el ejemplo de
-- "índice que existe pero no se usa" y se vuelve útil si el catálogo
-- crece.
-- ---------------------------------------------------------------------
CREATE INDEX idx_vino_nombre_lower
    ON vino (lower(nombre) text_pattern_ops);

-- Refrescar estadísticas de las tablas del sistema (solo las propias: el
-- propietario no puede analizar el catálogo de PostgreSQL).
ANALYZE comprobante, renglon_comprobante, cliente, vino, transferencia, renglon_transferencia,
        ingreso, renglon_ingreso, stock_sala, stock_deposito, empleado, lote_uva;
