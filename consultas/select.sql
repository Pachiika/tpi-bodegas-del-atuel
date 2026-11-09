SET client_encoding = 'UTF8';
-- =============================================
-- select.sql - Consultas S1 a S12
--
-- Los periodos ("ultima semana", "ultimo mes", etc.) se calculan
-- desde la fecha de hoy (CURRENT_DATE), no con fechas fijas.
-- Los valores "determinados" (sala 1, vino 1, etc.) se pueden cambiar.
-- =============================================


-- S1. Ranking de los 10 vinos con mas botellas vendidas en toda la red.
SELECT v.cod_vino, v.nombre, v.anada, SUM(rc.cantidad) AS botellas_vendidas
FROM renglon_comprobante rc
JOIN vino v ON v.cod_vino = rc.cod_vino
GROUP BY v.cod_vino, v.nombre, v.anada
ORDER BY botellas_vendidas DESC
LIMIT 10;


-- S2. Vinos que se vendieron en TODAS las salas (division relacional).
-- Se lee asi: "no existe ninguna sala donde ese vino no se haya vendido".
-- Son muchos: se muestran los primeros 20 y despues cuantos son en total.
SELECT v.cod_vino, v.nombre
FROM vino v
WHERE NOT EXISTS (
    SELECT 1
    FROM sala_venta s
    WHERE NOT EXISTS (
        SELECT 1
        FROM comprobante c
        JOIN renglon_comprobante rc ON rc.nro_comprobante = c.nro_comprobante
        WHERE c.id_sala = s.id_sala
          AND rc.cod_vino = v.cod_vino
    )
)
ORDER BY v.cod_vino
LIMIT 20;

SELECT COUNT(*) AS vinos_vendidos_en_todas_las_salas
FROM vino v
WHERE NOT EXISTS (
    SELECT 1
    FROM sala_venta s
    WHERE NOT EXISTS (
        SELECT 1
        FROM comprobante c
        JOIN renglon_comprobante rc ON rc.nro_comprobante = c.nro_comprobante
        WHERE c.id_sala = s.id_sala
          AND rc.cod_vino = v.cod_vino
    )
);


-- S3. Cantidad de clientes de cada tipo que compraron en la sala 1 en
-- la ultima semana. Con LEFT JOIN un tipo sin compras aparece con 0, y
-- COUNT(DISTINCT) no cuenta dos veces al que compro varias veces.
SELECT cl.tipo_cliente, COUNT(DISTINCT c.id_cliente) AS clientes
FROM cliente cl
LEFT JOIN comprobante c ON c.id_cliente = cl.id_cliente
                       AND c.id_sala = 1
                       AND c.fecha >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY cl.tipo_cliente
ORDER BY cl.tipo_cliente;


-- S4. Top 5 de salas que pidieron mas botellas del vino 1 por
-- transferencias en los ultimos 15 dias.
SELECT t.id_sala, l.nombre AS localidad, SUM(rt.cantidad) AS botellas_pedidas
FROM transferencia t
JOIN renglon_transferencia rt ON rt.nro_transferencia = t.nro_transferencia
JOIN sala_venta s ON s.id_sala = t.id_sala
JOIN localidad l ON l.codigo_postal = s.cp_localidad
WHERE rt.cod_vino = 1
  AND t.fecha_confeccion >= CURRENT_DATE - INTERVAL '15 days'
GROUP BY t.id_sala, l.nombre
ORDER BY botellas_pedidas DESC
LIMIT 5;


-- S5. Salas con menor cantidad de transferencias pendientes (no procesadas).
-- LEFT JOIN para que una sala sin pendientes cuente 0. Puede haber
-- varias salas empatadas en el minimo.
SELECT s.id_sala, l.nombre AS localidad, COUNT(t.nro_transferencia) AS pendientes
FROM sala_venta s
JOIN localidad l ON l.codigo_postal = s.cp_localidad
LEFT JOIN transferencia t ON t.id_sala = s.id_sala AND t.estado <> 'procesado'
GROUP BY s.id_sala, l.nombre
HAVING COUNT(t.nro_transferencia) = (
    SELECT MIN(cantidad)
    FROM (SELECT s2.id_sala, COUNT(t2.nro_transferencia) AS cantidad
          FROM sala_venta s2
          LEFT JOIN transferencia t2 ON t2.id_sala = s2.id_sala AND t2.estado <> 'procesado'
          GROUP BY s2.id_sala) AS conteo
)
ORDER BY s.id_sala;


-- S6. Para la sala 1, vinos sin stock en la sala pero con stock en el
-- deposito. fn_stock_sala devuelve 0 si la sala no tiene ese vino.
-- (Se muestran los primeros 20; sacar el LIMIT para verlos todos.)
SELECT v.cod_vino, v.nombre, d.cantidad AS stock_deposito
FROM vino v
JOIN stock_deposito d ON d.cod_vino = v.cod_vino
WHERE d.cantidad > 0
  AND fn_stock_sala(1, v.cod_vino) = 0
ORDER BY v.cod_vino
LIMIT 20;


-- S7. Empresa de transporte con mayor actividad en el ultimo mes
-- (la que hizo mas ingresos).
SELECT tr.codigo_transporte, tr.razon_social, COUNT(*) AS ingresos
FROM transportista tr
JOIN ingreso i ON i.codigo_transporte = tr.codigo_transporte
WHERE i.fecha >= CURRENT_DATE - INTERVAL '1 month'
GROUP BY tr.codigo_transporte, tr.razon_social
ORDER BY ingresos DESC
LIMIT 1;


-- S8. Monto total de ventas por sala en el ultimo trimestre, de mayor a menor.
SELECT s.id_sala, l.nombre AS localidad, COUNT(*) AS comprobantes, SUM(c.total) AS monto_total
FROM comprobante c
JOIN sala_venta s ON s.id_sala = c.id_sala
JOIN localidad l ON l.codigo_postal = s.cp_localidad
WHERE c.fecha >= CURRENT_DATE - INTERVAL '3 months'
GROUP BY s.id_sala, l.nombre
ORDER BY monto_total DESC;


-- =============================================
-- Consultas avanzadas
-- =============================================

-- S9. Ficha del vino 1: cepas con porcentajes, bodega, maridajes y
-- stock total (deposito + salas, de la vista vw_stock_total_vino).
-- Cepas y maridajes se juntan en un texto con string_agg.
SELECT v.cod_vino, v.nombre, v.tipo, v.anada, v.precio,
       b.razon_social AS bodega,
       (SELECT string_agg(ce.nombre || ' ' || cv.porcentaje || '%', ', ')
        FROM composicion_vino cv
        JOIN cepa ce ON ce.id_cepa = cv.id_cepa
        WHERE cv.cod_vino = v.cod_vino) AS cepas,
       (SELECT string_agg(m.nombre, ', ')
        FROM vino_maridaje vm
        JOIN maridaje m ON m.id_maridaje = vm.id_maridaje
        WHERE vm.cod_vino = v.cod_vino) AS maridajes,
       st.stock_total
FROM vino v
JOIN bodega b ON b.cuit = v.cuit_bodega
JOIN vw_stock_total_vino st ON st.cod_vino = v.cod_vino
WHERE v.cod_vino = 1;


-- S10. Rendimiento (kg por hectarea) de cada parcela y campaña, y las
-- parcelas que rinden menos que el promedio de su finca en esa campaña.
-- El CTE calcula el rendimiento y la subconsulta correlacionada el
-- promedio de la misma finca. (Se muestran las primeras 20.)
WITH rendimiento AS (
    SELECT l.id_finca, l.nro_parcela, l.campania,
           ROUND(l.kilos_cosechados / p.superficie_ha, 1) AS kg_por_ha
    FROM lote_uva l
    JOIN parcela p ON p.id_finca = l.id_finca AND p.nro_parcela = l.nro_parcela
)
SELECT r.id_finca, r.nro_parcela, r.campania, r.kg_por_ha
FROM rendimiento r
WHERE r.kg_por_ha < (SELECT AVG(r2.kg_por_ha)
                     FROM rendimiento r2
                     WHERE r2.id_finca = r.id_finca
                       AND r2.campania = r.campania)
ORDER BY r.id_finca, r.campania, r.nro_parcela
LIMIT 20;


-- S11 a) Ranking de vinos dentro de cada sala por botellas vendidas.
-- RANK() OVER (PARTITION BY sala) numera los vinos de cada sala por
-- separado. Se muestran los 3 primeros de las salas 1 a 5.
SELECT *
FROM (SELECT c.id_sala, rc.cod_vino, SUM(rc.cantidad) AS botellas,
             RANK() OVER (PARTITION BY c.id_sala ORDER BY SUM(rc.cantidad) DESC) AS puesto
      FROM comprobante c
      JOIN renglon_comprobante rc ON rc.nro_comprobante = c.nro_comprobante
      GROUP BY c.id_sala, rc.cod_vino) AS ranking
WHERE puesto <= 3 AND id_sala <= 5
ORDER BY id_sala, puesto;


-- S11 b) Ventas acumuladas mes a mes de la sala 1 en el año actual.
-- SUM() OVER (ORDER BY mes) va sumando los meses anteriores.
SELECT id_sala, mes, monto_total AS ventas_del_mes,
       SUM(monto_total) OVER (PARTITION BY id_sala ORDER BY mes) AS acumulado
FROM vw_ventas_mensuales_sala
WHERE id_sala = 1
  AND mes >= date_trunc('year', CURRENT_DATE)
ORDER BY mes;


-- S12 a) Clientes que compraron TODOS los vinos de "Bodega Salto de las
-- Rosas S.A." (division): no existe un vino de esa bodega que el
-- cliente no haya comprado.
SELECT cl.id_cliente, cl.nombre_o_razon_social, cl.tipo_cliente
FROM cliente cl
WHERE NOT EXISTS (
    SELECT 1
    FROM vino v
    JOIN bodega b ON b.cuit = v.cuit_bodega
    WHERE b.razon_social = 'Bodega Salto de las Rosas S.A.'
      AND NOT EXISTS (
          SELECT 1
          FROM comprobante c
          JOIN renglon_comprobante rc ON rc.nro_comprobante = c.nro_comprobante
          WHERE c.id_cliente = cl.id_cliente
            AND rc.cod_vino = v.cod_vino
      )
)
ORDER BY cl.id_cliente;


-- S12 b) Clientes que nunca compraron un vino tinto (anti-join).
-- Se muestran los primeros 20 y cuantos son en total.
SELECT cl.id_cliente, cl.nombre_o_razon_social, cl.tipo_cliente
FROM cliente cl
WHERE NOT EXISTS (
    SELECT 1
    FROM comprobante c
    JOIN renglon_comprobante rc ON rc.nro_comprobante = c.nro_comprobante
    JOIN vino v ON v.cod_vino = rc.cod_vino
    WHERE c.id_cliente = cl.id_cliente
      AND v.tipo = 'tinto'
)
ORDER BY cl.id_cliente
LIMIT 20;

SELECT COUNT(*) AS clientes_que_nunca_compraron_tinto
FROM cliente cl
WHERE NOT EXISTS (
    SELECT 1
    FROM comprobante c
    JOIN renglon_comprobante rc ON rc.nro_comprobante = c.nro_comprobante
    JOIN vino v ON v.cod_vino = rc.cod_vino
    WHERE c.id_cliente = cl.id_cliente
      AND v.tipo = 'tinto'
);
