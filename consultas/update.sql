SET client_encoding = 'UTF8';
-- U1: Recalcula totales de comprobantes según el descuento del cliente (triggers actualizan subtotales; modifica datos de prueba para forzar cambios).
BEGIN;

UPDATE cliente
SET descuento = 35
WHERE tipo_cliente = 'exportador'
  AND id_cliente IN (SELECT id_cliente FROM permiso_exportacion
                     GROUP BY id_cliente HAVING COUNT(*) > 3);

SELECT COUNT(DISTINCT r.nro_comprobante) AS comprobantes_a_recalcular
FROM renglon_comprobante r
JOIN comprobante c ON c.nro_comprobante = r.nro_comprobante
JOIN cliente cl ON cl.id_cliente = c.id_cliente
WHERE r.descuento_aplicado <> cl.descuento;

UPDATE renglon_comprobante r
SET descuento_aplicado = cl.descuento
FROM comprobante c, cliente cl
WHERE c.nro_comprobante = r.nro_comprobante
  AND cl.id_cliente = c.id_cliente
  AND r.descuento_aplicado <> cl.descuento;

-- Despues: no queda ninguno distinto y los totales coinciden con la funcion
SELECT COUNT(*) AS renglones_con_otro_descuento
FROM renglon_comprobante r
JOIN comprobante c ON c.nro_comprobante = r.nro_comprobante
JOIN cliente cl ON cl.id_cliente = c.id_cliente
WHERE r.descuento_aplicado <> cl.descuento;

SELECT COUNT(*) AS totales_mal_calculados
FROM comprobante
WHERE total <> fn_total_comprobante(nro_comprobante);

ROLLBACK;


-- U2: Incrementa 20% el sueldo al personal con más de 5 años en la empresa.
BEGIN;

SELECT COUNT(*) AS empleados, SUM(salario) AS total_salarios_antes
FROM empleado
WHERE fn_antiguedad_anios(fecha_ingreso) > 5;

UPDATE empleado
SET salario = ROUND(salario * 1.20, 2)
WHERE fn_antiguedad_anios(fecha_ingreso) > 5;

SELECT COUNT(*) AS empleados, SUM(salario) AS total_salarios_despues
FROM empleado
WHERE fn_antiguedad_anios(fecha_ingreso) > 5;

ROLLBACK;


-- U3: Aumenta 13% precios de Bodega Atuel Viejo (registrado en auditoría_precio).
BEGIN;

SELECT COUNT(*) AS vinos, ROUND(AVG(precio), 2) AS precio_promedio_antes,
       (SELECT COUNT(*) FROM auditoria_precio) AS filas_auditoria_antes
FROM vino
WHERE cuit_bodega = (SELECT cuit FROM bodega WHERE razon_social = 'Bodega Atuel Viejo S.A.');

UPDATE vino
SET precio = ROUND(precio * 1.13, 2)
WHERE cuit_bodega = (SELECT cuit FROM bodega WHERE razon_social = 'Bodega Atuel Viejo S.A.');

SELECT COUNT(*) AS vinos, ROUND(AVG(precio), 2) AS precio_promedio_despues,
       (SELECT COUNT(*) FROM auditoria_precio) AS filas_auditoria_despues
FROM vino
WHERE cuit_bodega = (SELECT cuit FROM bodega WHERE razon_social = 'Bodega Atuel Viejo S.A.');

ROLLBACK;


-- U4: Intercambia los días de cierre entre lunes y miércoles para las salas (en una sola sentencia usando CASE).
BEGIN;

SELECT dia_cierre, COUNT(*) AS salas
FROM sala_venta
WHERE dia_cierre IN ('lunes', 'miercoles')
GROUP BY dia_cierre;

UPDATE sala_venta
SET dia_cierre = CASE
                     WHEN dia_cierre = 'lunes' THEN 'miercoles'
                     WHEN dia_cierre = 'miercoles' THEN 'lunes'
                 END
WHERE dia_cierre IN ('lunes', 'miercoles');

SELECT dia_cierre, COUNT(*) AS salas
FROM sala_venta
WHERE dia_cierre IN ('lunes', 'miercoles')
GROUP BY dia_cierre;

ROLLBACK;


-- U5: Rebaja 15% el precio del top 10 de vinos con menor venta (admite ceros vía LEFT JOIN).
BEGIN;

-- Los 10 vinos menos vendidos
SELECT v.cod_vino, v.nombre, v.precio AS precio_antes,
       COALESCE(SUM(rc.cantidad), 0) AS botellas_vendidas
FROM vino v
LEFT JOIN renglon_comprobante rc ON rc.cod_vino = v.cod_vino
GROUP BY v.cod_vino, v.nombre, v.precio
ORDER BY botellas_vendidas, v.cod_vino
LIMIT 10;

UPDATE vino
SET precio = ROUND(precio * 0.85, 2)
WHERE cod_vino IN (SELECT v.cod_vino
                   FROM vino v
                   LEFT JOIN renglon_comprobante rc ON rc.cod_vino = v.cod_vino
                   GROUP BY v.cod_vino
                   ORDER BY COALESCE(SUM(rc.cantidad), 0), v.cod_vino
                   LIMIT 10);

-- Los cambios quedaron en la auditoria
SELECT cod_vino, precio_anterior, precio_nuevo, usuario
FROM auditoria_precio
WHERE fecha_hora >= now() - INTERVAL '1 minute'
ORDER BY cod_vino;

ROLLBACK;


-- U6. A los exportadores con mas de 3 permisos de exportacion subirles el descuento al 35 %.
BEGIN;

SELECT descuento, COUNT(*) AS exportadores
FROM cliente
WHERE tipo_cliente = 'exportador'
GROUP BY descuento;

UPDATE cliente
SET descuento = 35
WHERE tipo_cliente = 'exportador'
  AND id_cliente IN (SELECT id_cliente
                     FROM permiso_exportacion
                     GROUP BY id_cliente
                     HAVING COUNT(*) > 3);

SELECT descuento, COUNT(*) AS exportadores
FROM cliente
WHERE tipo_cliente = 'exportador'
GROUP BY descuento;

ROLLBACK;
