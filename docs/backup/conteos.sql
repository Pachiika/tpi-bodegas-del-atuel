-- Conteo exacto de filas por tabla (para comparar origen y restauración).
SELECT 'cliente' AS tabla, count(*) FROM cliente UNION ALL
SELECT 'comprobante', count(*) FROM comprobante UNION ALL
SELECT 'renglon_comprobante', count(*) FROM renglon_comprobante UNION ALL
SELECT 'vino', count(*) FROM vino UNION ALL
SELECT 'stock_sala', count(*) FROM stock_sala UNION ALL
SELECT 'transferencia', count(*) FROM transferencia UNION ALL
SELECT 'ingreso', count(*) FROM ingreso UNION ALL
SELECT 'auditoria_precio', count(*) FROM auditoria_precio UNION ALL
SELECT 'SUMA total comprobantes', sum(total)::bigint FROM comprobante
ORDER BY 1;
