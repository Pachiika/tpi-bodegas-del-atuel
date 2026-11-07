-- =====================================================================
-- BODEGAS DEL ATUEL - CONSULTAS SELECT AVANZADAS (consultas/select.sql)
-- =====================================================================

-- S1: Listar el stock total de cada vino utilizando la vista creada
SELECT * FROM vw_stock_total_vino ORDER BY stock_total DESC;

-- S2: Consultar documentos de ingresos o transferencias pendientes de procesamiento
SELECT * FROM vw_documentos_pendientes ORDER BY fecha ASC;

-- S3: Ventas mensuales agrupadas por sala utilizando la vista analítica
SELECT * FROM vw_ventas_mensuales_sala ORDER BY anio DESC, mes DESC, monto_total_ventas DESC;

-- S4: Utilizar CTE (Common Table Expression) para calcular el total de ventas por cliente y filtrar los VIP (> 100000)
WITH ventas_cliente AS (
    SELECT 
        c.id_cliente,
        c.nombre_o_razon_social,
        c.tipo_cliente,
        COUNT(co.nro_comprobante) AS total_comprobantes,
        SUM(co.total) AS monto_acumulado
    FROM cliente c
    JOIN comprobante co ON c.id_cliente = co.id_cliente
    GROUP BY c.id_cliente, c.nombre_o_razon_social, c.tipo_cliente
)
SELECT * FROM ventas_cliente 
WHERE monto_acumulado > 100000.00 
ORDER BY monto_acumulado DESC;

-- S5: Ranking de vinos más vendidos usando funciones de ventana (ROW_NUMBER / RANK)
SELECT 
    v.nombre,
    v.tipo,
    SUM(rc.cantidad) AS total_unidades_vendidas,
    RANK() OVER (ORDER BY SUM(rc.cantidad) DESC) as ranking_ventas
FROM vino v
JOIN renglon_comprobante rc ON v.cod_vino = rc.cod_vino
GROUP BY v.cod_vino, v.nombre, v.tipo;

-- S6: Historial de auditoría de precios de un vino específico con el usuario que lo modificó
SELECT 
    v.nombre,
    ap.precio_anterior,
    ap.precio_nuevo,
    ap.fecha_hora,
    ap.usuario
FROM auditoria_precio ap
JOIN vino v ON ap.cod_vino = v.cod_vino
ORDER BY ap.fecha_hora DESC;