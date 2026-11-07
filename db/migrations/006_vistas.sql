-- =====================================================================
-- 006_vistas.sql - Vistas del Sistema
-- =====================================================================

-- 1. Vista de stock total por vino (Depósito central + la suma de todas las salas)
CREATE OR REPLACE VIEW vw_stock_total_vino AS
SELECT 
    v.cod_vino,
    v.nombre,
    v.anada,
    v.volumen_ml,
    COALESCE(sd.cantidad, 0) AS stock_deposito,
    COALESCE(SUM(ss.cantidad), 0) AS stock_en_salas,
    COALESCE(sd.cantidad, 0) + COALESCE(SUM(ss.cantidad), 0) AS stock_total
FROM vino v
LEFT JOIN stock_deposito sd ON v.cod_vino = sd.cod_vino
LEFT JOIN stock_sala ss ON v.cod_vino = ss.cod_vino
GROUP BY v.cod_vino, v.nombre, v.anada, v.volumen_ml, sd.cantidad;

-- 2. Vista de documentos pendientes de procesamiento (ingresos y transferencias)
CREATE OR REPLACE VIEW vw_documentos_pendientes AS
SELECT 
    'ingreso' AS tipo_documento,
    codigo_ingreso AS nro_o_codigo,
    estado::text,
    fecha
FROM ingreso
WHERE estado <> 'procesado'
UNION ALL
SELECT 
    'transferencia' AS tipo_documento,
    nro_transferencia AS nro_o_codigo,
    estado::text,
    fecha_confeccion AS fecha
FROM transferencia
WHERE estado <> 'procesado';

-- 3. Vista de ventas mensuales por sala
CREATE OR REPLACE VIEW vw_ventas_mensuales_sala AS
SELECT 
    s.id_sala,
    (l.nombre || ' - Calle ' || s.calle || ' ' || s.numero) AS sala_ubicacion,
    EXTRACT(YEAR FROM c.fecha) AS anio,
    EXTRACT(MONTH FROM c.fecha) AS mes,
    COUNT(c.nro_comprobante) AS cantidad_comprobantes,
    SUM(c.total) AS monto_total_ventas
FROM comprobante c
JOIN sala_venta s ON c.id_sala = s.id_sala
JOIN localidad l ON s.cp_localidad = l.codigo_postal
GROUP BY s.id_sala, sala_ubicacion, anio, mes;