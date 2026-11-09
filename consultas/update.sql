SET client_encoding = 'UTF8';
-- =============================================
-- update.sql - Consultas U1 a U6
--
-- Cada consulta esta entre BEGIN y ROLLBACK: se ve como quedan los
-- datos antes y despues del UPDATE, pero al final se deshace todo y la
-- base queda igual. (Para guardar de verdad, cambiar ROLLBACK por COMMIT.)
-- =============================================


-- U1. Recalcular el total de todos los comprobantes aplicando el
-- descuento que corresponde al tipo de cliente.
-- El descuento de cada cliente esta en cliente.descuento. Actualizamos
-- los renglones que tienen otro descuento y los triggers recalculan
-- el subtotal del renglon y el total del comprobante.
-- Con los datos recien cargados todos coinciden, asi que primero
-- cambiamos el descuento de algunos exportadores (como en U6) para
-- que haya algo que recalcular.
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


-- U2. Aumentar un 20 % el salario de los empleados con mas de 5 años
-- de antiguedad (fn_antiguedad_anios cuenta los años desde el ingreso).
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


-- U3. Incrementar un 13 % el precio de los vinos de "Bodega Atuel Viejo S.A.".
-- Cada cambio de precio queda registrado en auditoria_precio (trigger RN-13).
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


-- U4. En las salas que cierran el lunes pasar el cierre al miercoles y
-- al reves, en una sola sentencia. El CASE usa el valor que tenia cada
-- fila antes del cambio, por eso no se mezclan.
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


-- U5. Aplicar un 15 % de descuento de precio a los 10 vinos menos
-- vendidos. LEFT JOIN para que un vino que nunca se vendio cuente 0.
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


-- U6. A los exportadores con mas de 3 permisos de exportacion subirles
-- el descuento al 35 %.
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
