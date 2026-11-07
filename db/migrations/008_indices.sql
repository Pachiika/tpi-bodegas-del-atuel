-- =====================================================================
-- 008_indices.sql - Optimización y Rendimiento
-- =====================================================================

-- 1. Índice compuesto para optimizar búsquedas de comprobantes por sala y fecha
CREATE INDEX idx_comprobante_sala_fecha 
ON comprobante (id_sala, fecha);

-- 2. Índice parcial para optimizar transferencias pendientes (tabla chica sobre tabla grande)[cite: 29]
CREATE INDEX idx_transferencia_pendientes 
ON transferencia (id_sala, fecha_confeccion) 
WHERE estado <> 'procesado';

-- 3. Índices sobre claves foráneas que PostgreSQL no indexa automáticamente[cite: 16]
CREATE INDEX idx_empleado_sala 
ON empleado (id_sala);

CREATE INDEX idx_vino_bodega 
ON vino (cuit_bodega);

CREATE INDEX idx_comprobante_cliente 
ON comprobante (id_cliente);