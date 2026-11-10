SET client_encoding = 'UTF8';
-- I1: Inserta cobertura General Alvear para el transportista con menos envíos trimestrales.
BEGIN;

-- Envios de cada transportista en los ultimos 3 meses.
-- LEFT JOIN para que los que no hicieron ninguno aparezcan con 0.
SELECT t.codigo_transporte, t.razon_social, COUNT(i.codigo_ingreso) AS envios
FROM transportista t
LEFT JOIN ingreso i ON i.codigo_transporte = t.codigo_transporte
                   AND i.fecha >= CURRENT_DATE - INTERVAL '3 months'
GROUP BY t.codigo_transporte, t.razon_social
ORDER BY envios, t.codigo_transporte
LIMIT 3;

INSERT INTO transportista_cubre_localidad (codigo_transporte, cp_localidad)
SELECT
    (SELECT t.codigo_transporte
     FROM transportista t
     LEFT JOIN ingreso i ON i.codigo_transporte = t.codigo_transporte
                        AND i.fecha >= CURRENT_DATE - INTERVAL '3 months'
     GROUP BY t.codigo_transporte
     ORDER BY COUNT(i.codigo_ingreso), t.codigo_transporte
     LIMIT 1),
    l.codigo_postal
FROM localidad l
WHERE l.nombre = 'General Alvear';

-- Transportistas que ahora cubren General Alvear
SELECT tc.codigo_transporte, t.razon_social, l.nombre AS localidad
FROM transportista_cubre_localidad tc
JOIN transportista t ON t.codigo_transporte = tc.codigo_transporte
JOIN localidad l ON l.codigo_postal = tc.cp_localidad
WHERE l.nombre = 'General Alvear';

ROLLBACK;


-- I2. Si existe algun vino tinto con graduacion de 14 o mas, crear el
-- maridaje "Cordero al disco" y asociarlo a todos esos vinos.
BEGIN;

SELECT COUNT(*) AS tintos_14_o_mas
FROM vino
WHERE tipo = 'tinto' AND graduacion >= 14;

-- Solo se crea si existe al menos un vino que cumpla
INSERT INTO maridaje (nombre, temperatura_servicio)
SELECT 'Cordero al disco', 17
WHERE EXISTS (SELECT 1 FROM vino WHERE tipo = 'tinto' AND graduacion >= 14);

INSERT INTO vino_maridaje (cod_vino, id_maridaje)
SELECT v.cod_vino, m.id_maridaje
FROM vino v, maridaje m
WHERE v.tipo = 'tinto'
  AND v.graduacion >= 14
  AND m.nombre = 'Cordero al disco';

SELECT m.nombre, COUNT(vm.cod_vino) AS vinos_asociados
FROM maridaje m
JOIN vino_maridaje vm ON vm.id_maridaje = m.id_maridaje
WHERE m.nombre = 'Cordero al disco'
GROUP BY m.nombre;

ROLLBACK;


-- I3: Inserta comprobante (3 renglones) para cliente 1 en sala 1; cálculos y stock automáticos por triggers.
BEGIN;

-- Tres vinos con stock en la sala 1
SELECT cod_vino, cantidad AS stock_antes
FROM stock_sala
WHERE id_sala = 1 AND cantidad >= 2
ORDER BY cod_vino
LIMIT 3;

INSERT INTO comprobante (id_cliente, id_sala) VALUES (1, 1);

-- currval devuelve el numero de comprobante que se acaba de crear
INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad)
SELECT currval('comprobante_nro_comprobante_seq'), cod_vino, 2
FROM stock_sala
WHERE id_sala = 1 AND cantidad >= 2
ORDER BY cod_vino
LIMIT 3;

SELECT cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal
FROM renglon_comprobante
WHERE nro_comprobante = currval('comprobante_nro_comprobante_seq');

SELECT nro_comprobante, subtotal, descuento, total,
       fn_total_comprobante(nro_comprobante) AS total_segun_funcion
FROM comprobante
WHERE nro_comprobante = currval('comprobante_nro_comprobante_seq');

ROLLBACK;


-- I4. Insertar una nueva bodega.
BEGIN;

SELECT COUNT(*) AS bodegas_antes FROM bodega;

INSERT INTO bodega (cuit, razon_social, domicilio)
VALUES ('30715558881', 'Bodega Los Toneles del Sur S.A.', 'Ruta Nacional 143 km 12, San Rafael');

SELECT COUNT(*) AS bodegas_despues FROM bodega;

ROLLBACK;


-- I5. Insertar una nueva sala de venta (el id lo pone el SERIAL).
BEGIN;

SELECT COUNT(*) AS salas_antes FROM sala_venta;

INSERT INTO sala_venta (calle, numero, dia_cierre, cp_localidad)
VALUES ('Av. Libertador', '850', 'domingo', '5620');

SELECT COUNT(*) AS salas_despues FROM sala_venta;

ROLLBACK;


-- I6: Inserta ingreso en confección (120 botellas de Malbec Reserva, transp. 1); sin impacto en stock hasta procesar.
BEGIN;

INSERT INTO ingreso (codigo_transporte, cuit_bodega)
SELECT 1, cuit
FROM bodega
WHERE razon_social = 'Bodega Atuel Viejo S.A.';

INSERT INTO renglon_ingreso (codigo_ingreso, cod_vino, cantidad)
SELECT currval('ingreso_codigo_ingreso_seq'), v.cod_vino, 120
FROM vino v
JOIN bodega b ON b.cuit = v.cuit_bodega
WHERE v.nombre = 'Malbec Reserva'
  AND v.volumen_ml = 750
  AND b.razon_social = 'Bodega Atuel Viejo S.A.'
ORDER BY v.anada DESC
LIMIT 1;

SELECT i.codigo_ingreso, i.fecha, i.estado, t.razon_social AS transportista,
       b.razon_social AS bodega, v.nombre, v.anada, r.cantidad
FROM ingreso i
JOIN transportista t ON t.codigo_transporte = i.codigo_transporte
JOIN bodega b ON b.cuit = i.cuit_bodega
JOIN renglon_ingreso r ON r.codigo_ingreso = i.codigo_ingreso
JOIN vino v ON v.cod_vino = r.cod_vino
WHERE i.codigo_ingreso = currval('ingreso_codigo_ingreso_seq');

ROLLBACK;
