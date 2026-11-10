-- 008_indices.sql: Creación de índices estratégicos basados en planes de ejecución (EXPLAIN ANALYZE) para optimizar consultas y claves foráneas.
SET client_encoding = 'UTF8';   -- los archivos estan en UTF-8 (acentos bien tambien en Windows)

-- Índice en comprobante(id_cliente): optimiza drásticamente el rendimiento en consultas de compras y validaciones de FK, reduciendo tiempos de ~70s a ~0.5s en operaciones complejas.
CREATE INDEX idx_comprobante_cliente
    ON comprobante (id_cliente);

-- Índice compuesto comprobante(id_sala, fecha): optimiza consultas por sala y rango de fechas ordenando primero por igualdad y luego por rango, sirviendo además para la clave foránea.
CREATE INDEX idx_comprobante_sala_fecha
    ON comprobante (id_sala, fecha);

-- Índice cubriente en renglon_comprobante(cod_vino) INCLUDE (cantidad): optimiza búsquedas por vino y validaciones de FK (RN-14) mediante Index Only Scans sin acceder a la tabla base.
CREATE INDEX idx_rc_vino_incl_cantidad
    ON renglon_comprobante (cod_vino) INCLUDE (cantidad);

-- Índice BRIN en comprobante(fecha): aprovecha la correlación física cronológica para ofrecer un índice ultraligero que acelera consultas por período (S8) omitiendo bloques de páginas irrelevantes.
CREATE INDEX idx_comprobante_fecha_brin
    ON comprobante USING brin (fecha) WITH (pages_per_range = 32);

-- Índice parcial para transferencias pendientes: indexa exclusivamente los registros no procesados, optimizando consultas frecuentes (S5 y vistas) con un costo de mantenimiento mínimo.
CREATE INDEX idx_transferencia_pendientes
    ON transferencia (id_sala, fecha_confeccion)
    WHERE estado <> 'procesado';

-- Índices restantes sobre claves foráneas: optimizan operaciones de JOIN y validaciones de integridad en borrados (CASCADE/RESTRICT) para tablas secundarias del sistema.
CREATE INDEX idx_empleado_sala            ON empleado (id_sala);
CREATE INDEX idx_vino_bodega              ON vino (cuit_bodega);
CREATE INDEX idx_ingreso_transportista    ON ingreso (codigo_transporte, fecha);
CREATE INDEX idx_renglon_transf_vino      ON renglon_transferencia (cod_vino);
CREATE INDEX idx_renglon_ingreso_vino     ON renglon_ingreso (cod_vino);
CREATE INDEX idx_stock_sala_vino          ON stock_sala (cod_vino);
CREATE INDEX idx_lote_bodega              ON lote_uva (cuit_bodega_destino);

-- Índice de expresión lower(nombre) con text_pattern_ops: optimiza búsquedas por prefijo sin distinguir mayúsculas, diseñado anticipándose al crecimiento del catálogo de vinos.
CREATE INDEX idx_vino_nombre_lower
    ON vino (lower(nombre) text_pattern_ops);

-- Refrescar estadísticas de las tablas del sistema (solo las propias: el propietario no puede analizar el catálogo de PostgreSQL).
ANALYZE comprobante, renglon_comprobante, cliente, vino, transferencia, renglon_transferencia,
        ingreso, renglon_ingreso, stock_sala, stock_deposito, empleado, lote_uva;
