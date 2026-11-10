SET client_encoding = 'UTF8';
-- D1: Elimina comprobantes de socios con más de 5 años (renglones en cascada).

SELECT COUNT(*) AS comprobantes_antes
FROM comprobante
WHERE fecha < CURRENT_DATE - INTERVAL '5 years'
  AND id_cliente IN (SELECT id_cliente FROM cliente WHERE tipo_cliente = 'socio');

DELETE FROM comprobante
WHERE fecha < CURRENT_DATE - INTERVAL '5 years'
  AND id_cliente IN (SELECT id_cliente FROM cliente WHERE tipo_cliente = 'socio');

SELECT COUNT(*) AS comprobantes_despues
FROM comprobante
WHERE fecha < CURRENT_DATE - INTERVAL '5 years'
  AND id_cliente IN (SELECT id_cliente FROM cliente WHERE tipo_cliente = 'socio');

ROLLBACK;


-- D2: Borra cepas sin uso en vinos o parcelas (inserta una de prueba previamente).
BEGIN;

INSERT INTO cepa (nombre, tipo) VALUES ('Cepa de prueba sin uso', 'blanca');

SELECT id_cepa, nombre
FROM cepa c
WHERE NOT EXISTS (SELECT 1 FROM composicion_vino cv WHERE cv.id_cepa = c.id_cepa)
  AND NOT EXISTS (SELECT 1 FROM parcela p WHERE p.id_cepa = c.id_cepa);

DELETE FROM cepa c
WHERE NOT EXISTS (SELECT 1 FROM composicion_vino cv WHERE cv.id_cepa = c.id_cepa)
  AND NOT EXISTS (SELECT 1 FROM parcela p WHERE p.id_cepa = c.id_cepa);

SELECT COUNT(*) AS cepas_sin_uso_que_quedan
FROM cepa c
WHERE NOT EXISTS (SELECT 1 FROM composicion_vino cv WHERE cv.id_cepa = c.id_cepa)
  AND NOT EXISTS (SELECT 1 FROM parcela p WHERE p.id_cepa = c.id_cepa);

ROLLBACK;


-- D3: Elimina empleados de la sala cerrada de Malargüe con menos de 2 años de antigüedad.
BEGIN;

SELECT e.cuit, e.nombre, e.fecha_ingreso, fn_antiguedad_anios(e.fecha_ingreso) AS anios
FROM empleado e
JOIN sala_venta s ON s.id_sala = e.id_sala
JOIN localidad l ON l.codigo_postal = s.cp_localidad
WHERE l.nombre = 'Malargüe'
ORDER BY e.fecha_ingreso;

DELETE FROM empleado
WHERE fn_antiguedad_anios(fecha_ingreso) < 2
  AND id_sala IN (SELECT s.id_sala
                  FROM sala_venta s
                  JOIN localidad l ON l.codigo_postal = s.cp_localidad
                  WHERE l.nombre = 'Malargüe');

SELECT COUNT(*) AS empleados_que_quedan
FROM empleado e
JOIN sala_venta s ON s.id_sala = e.id_sala
JOIN localidad l ON l.codigo_postal = s.cp_localidad
WHERE l.nombre = 'Malargüe';

ROLLBACK;


-- D4: Elimina socios sin compras registrados hace más de 5 años.
BEGIN;

SELECT COUNT(*) AS socios_a_borrar
FROM cliente c
WHERE c.tipo_cliente = 'socio'
  AND c.fecha_alta < CURRENT_DATE - INTERVAL '5 years'
  AND NOT EXISTS (SELECT 1 FROM comprobante x WHERE x.id_cliente = c.id_cliente);

DELETE FROM cliente c
WHERE c.tipo_cliente = 'socio'
  AND c.fecha_alta < CURRENT_DATE - INTERVAL '5 years'
  AND NOT EXISTS (SELECT 1 FROM comprobante x WHERE x.id_cliente = c.id_cliente);

SELECT COUNT(*) AS clientes_que_quedan FROM cliente;

ROLLBACK;


-- D5: Elimina ingresos procesados de >365 días (renglones en CASCADE; permitido por trigger).
BEGIN;

SELECT COUNT(*) AS ingresos_a_borrar
FROM ingreso
WHERE estado = 'procesado' AND fecha < CURRENT_DATE - 365;

DELETE FROM ingreso
WHERE estado = 'procesado' AND fecha < CURRENT_DATE - 365;

SELECT COUNT(*) AS ingresos_que_quedan FROM ingreso;

ROLLBACK;


-- D6. Borrar los socios sin compras que viven en Bowen.
BEGIN;

SELECT c.id_cliente, c.nombre_o_razon_social, c.fecha_alta
FROM cliente c
JOIN localidad l ON l.codigo_postal = c.cp_localidad
WHERE l.nombre = 'Bowen'
  AND c.tipo_cliente = 'socio'
  AND NOT EXISTS (SELECT 1 FROM comprobante x WHERE x.id_cliente = c.id_cliente)
ORDER BY c.id_cliente;

DELETE FROM cliente c
WHERE c.tipo_cliente = 'socio'
  AND c.cp_localidad IN (SELECT codigo_postal FROM localidad WHERE nombre = 'Bowen')
  AND NOT EXISTS (SELECT 1 FROM comprobante x WHERE x.id_cliente = c.id_cliente);

SELECT COUNT(*) AS socios_sin_compras_que_quedan
FROM cliente c
JOIN localidad l ON l.codigo_postal = c.cp_localidad
WHERE l.nombre = 'Bowen'
  AND c.tipo_cliente = 'socio'
  AND NOT EXISTS (SELECT 1 FROM comprobante x WHERE x.id_cliente = c.id_cliente);

ROLLBACK;