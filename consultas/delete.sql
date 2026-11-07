-- =====================================================================
-- BODEGAS DEL ATUEL - CONSULTAS DE BORRADO (consultas/delete.sql)
-- =====================================================================

-- D1: Eliminar un registro de auditoría de precios antiguo
DELETE FROM auditoria_precio 
WHERE fecha_hora < '2025-01-01';

-- D2: Eliminar un maridaje que no esté asociado a ningún vino
DELETE FROM maridaje 
WHERE id_maridaje NOT IN (SELECT DISTINCT id_maridaje FROM vino_maridaje);

-- D3: Eliminar un renglón de una transferencia que aún está en confección
DELETE FROM renglon_transferencia 
WHERE nro_transferencia = 1 AND cod_vino = 2;

-- D4: Eliminar un permiso de exportación vencido
DELETE FROM permiso_exportacion 
WHERE fecha_vencimiento < CURRENT_DATE - INTERVAL '1 year';

-- D5: Borrar un lote de uva de prueba que no tenga análisis de calidad asociados
DELETE FROM lote_uva 
WHERE nro_lote NOT IN (SELECT DISTINCT nro_lote FROM analisis_calidad) 
  AND campania < 2022;

-- D6: Eliminar un transportista que no tenga localidades asignadas ni ingresos asociados
DELETE FROM transportista 
WHERE codigo_transporte NOT IN (SELECT DISTINCT codigo_transporte FROM transportista_cubre_localidad)
  AND codigo_transporte NOT IN (SELECT DISTINCT codigo_transporte FROM ingreso);