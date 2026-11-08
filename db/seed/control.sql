-- =====================================================================
-- db/seed/control.sql · Consultas de control de la carga masiva
-- Cada fila es una verificación y la cantidad de problemas encontrados.
-- Todas deben dar 0. (Se ejecuta automáticamente al final de seed.py.)
--     psql -d bodegas -f db/seed/control.sql
-- =====================================================================
SELECT 'Stock de sala negativo' AS verificacion,
       count(*)::int AS problemas
  FROM stock_sala WHERE cantidad < 0
UNION ALL
SELECT 'Stock de depósito negativo',
       count(*)::int FROM stock_deposito WHERE cantidad < 0
UNION ALL
SELECT 'Comprobantes cuyo total no coincide con la suma de renglones',
       count(*)::int
  FROM comprobante c
  LEFT JOIN (SELECT nro_comprobante, SUM(subtotal) AS suma
               FROM renglon_comprobante GROUP BY nro_comprobante) r
         ON r.nro_comprobante = c.nro_comprobante
 WHERE c.total <> COALESCE(r.suma, 0)
UNION ALL
SELECT 'Comprobantes sin renglones',
       count(*)::int
  FROM comprobante c
 WHERE NOT EXISTS (SELECT 1 FROM renglon_comprobante r WHERE r.nro_comprobante = c.nro_comprobante)
UNION ALL
SELECT 'Renglones con subtotal mal calculado',
       count(*)::int
  FROM renglon_comprobante
 WHERE subtotal <> fn_subtotal_renglon(cantidad, precio_unitario, descuento_aplicado)
UNION ALL
SELECT 'Renglones con descuento distinto al del tipo de cliente',
       count(*)::int
  FROM renglon_comprobante r
  JOIN comprobante c ON c.nro_comprobante = r.nro_comprobante
  JOIN cliente cl    ON cl.id_cliente = c.id_cliente
 WHERE r.descuento_aplicado <> fn_descuento_por_tipo(cl.tipo_cliente)
UNION ALL
SELECT 'Vinos cuya composición no suma 100',
       count(*)::int
  FROM vino v
  LEFT JOIN (SELECT cod_vino, SUM(porcentaje) AS suma FROM composicion_vino GROUP BY cod_vino) c
         ON c.cod_vino = v.cod_vino
 WHERE COALESCE(c.suma, 0) <> 100
UNION ALL
SELECT 'Ventas anteriores al alta del cliente',
       count(*)::int
  FROM comprobante c JOIN cliente cl ON cl.id_cliente = c.id_cliente
 WHERE c.fecha::date < cl.fecha_alta
UNION ALL
SELECT 'Vinos vendidos antes de su añada',
       count(*)::int
  FROM renglon_comprobante r
  JOIN comprobante c ON c.nro_comprobante = r.nro_comprobante
  JOIN vino v        ON v.cod_vino = r.cod_vino
 WHERE EXTRACT(YEAR FROM c.fecha) <= v.anada
UNION ALL
SELECT 'Clientes cuyos datos no coinciden con su tipo',
       count(*)::int FROM cliente
 WHERE NOT ((tipo_cliente = 'socio' AND zona_cobertura IS NULL AND pais_destino_principal IS NULL)
         OR (tipo_cliente = 'distribuidor' AND zona_cobertura IS NOT NULL AND pais_destino_principal IS NULL)
         OR (tipo_cliente = 'exportador' AND pais_destino_principal IS NOT NULL AND zona_cobertura IS NULL))
UNION ALL
SELECT 'Documentos procesados sin renglones',
       (SELECT count(*) FROM ingreso i WHERE NOT EXISTS
          (SELECT 1 FROM renglon_ingreso r WHERE r.codigo_ingreso = i.codigo_ingreso))::int
     + (SELECT count(*) FROM transferencia t WHERE NOT EXISTS
          (SELECT 1 FROM renglon_transferencia r WHERE r.nro_transferencia = t.nro_transferencia))::int
UNION ALL
SELECT 'Lotes cosechados fuera de febrero-abril',
       count(*)::int FROM lote_uva WHERE EXTRACT(MONTH FROM fecha_cosecha) NOT BETWEEN 2 AND 4
UNION ALL
SELECT 'Análisis de calidad anteriores a la cosecha',
       count(*)::int
  FROM analisis_calidad a JOIN lote_uva l ON l.nro_lote = a.nro_lote
 WHERE a.fecha < l.fecha_cosecha
UNION ALL
SELECT 'Tablas vacías',
       (SELECT count(*) FROM (VALUES
          ((SELECT count(*) FROM localidad)), ((SELECT count(*) FROM sala_venta)), ((SELECT count(*) FROM empleado)),
          ((SELECT count(*) FROM cepa)), ((SELECT count(*) FROM finca)),
          ((SELECT count(*) FROM parcela)), ((SELECT count(*) FROM bodega)), ((SELECT count(*) FROM lote_uva)),
          ((SELECT count(*) FROM analisis_calidad)), ((SELECT count(*) FROM vino)), ((SELECT count(*) FROM composicion_vino)),
          ((SELECT count(*) FROM maridaje)), ((SELECT count(*) FROM vino_maridaje)), ((SELECT count(*) FROM cliente)),
          ((SELECT count(*) FROM permiso_exportacion)),
          ((SELECT count(*) FROM comprobante)), ((SELECT count(*) FROM renglon_comprobante)), ((SELECT count(*) FROM stock_sala)),
          ((SELECT count(*) FROM stock_deposito)), ((SELECT count(*) FROM transportista)), ((SELECT count(*) FROM transportista_cubre_localidad)),
          ((SELECT count(*) FROM ingreso)), ((SELECT count(*) FROM renglon_ingreso)), ((SELECT count(*) FROM transferencia)),
          ((SELECT count(*) FROM renglon_transferencia)), ((SELECT count(*) FROM auditoria_precio))
        ) AS t(n) WHERE n = 0)::int;
