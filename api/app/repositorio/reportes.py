"""Reportes de solo lectura (consultas de la sección 8 del enunciado)."""
from psycopg import Connection

# S1 — ranking de vinos más vendidos en toda la red.
SQL_TOP_VINOS = """
SELECT v.cod_vino, v.nombre, v.anada, v.volumen_ml, SUM(rc.cantidad) AS botellas_vendidas
  FROM renglon_comprobante rc
  JOIN vino v ON v.cod_vino = rc.cod_vino
 GROUP BY v.cod_vino, v.nombre, v.anada, v.volumen_ml
 ORDER BY botellas_vendidas DESC, v.cod_vino
 LIMIT %s
"""


def top_vinos(conn: Connection, limite: int = 10) -> list[dict]:
    return conn.execute(SQL_TOP_VINOS, (limite,)).fetchall()


# S8 — monto vendido por sala en los últimos N meses (por defecto, el trimestre).
SQL_VENTAS_POR_SALA = """
SELECT s.id_sala, l.nombre || ' - ' || s.calle || ' ' || s.numero AS sala,
       count(*) AS comprobantes, SUM(c.total) AS monto_total
  FROM comprobante c
  JOIN sala_venta s ON s.id_sala = c.id_sala
  JOIN localidad  l ON l.codigo_postal = s.cp_localidad
 WHERE c.fecha >= CURRENT_DATE - make_interval(months => %s)
 GROUP BY s.id_sala, l.nombre, s.calle, s.numero
 ORDER BY monto_total DESC
"""


def ventas_por_sala(conn: Connection, meses: int = 3) -> list[dict]:
    return conn.execute(SQL_VENTAS_POR_SALA, (meses,)).fetchall()


# S6 — vinos sin stock en una sala pero con stock en el depósito.
SQL_VINOS_SIN_STOCK = """
SELECT v.cod_vino, v.nombre, v.anada, v.volumen_ml, d.cantidad AS stock_deposito
  FROM vino v
  JOIN stock_deposito d ON d.cod_vino = v.cod_vino AND d.cantidad > 0
 WHERE fn_stock_sala(%s, v.cod_vino) = 0
 ORDER BY d.cantidad DESC, v.cod_vino
"""


def vinos_sin_stock(conn: Connection, id_sala: int) -> list[dict]:
    return conn.execute(SQL_VINOS_SIN_STOCK, (id_sala,)).fetchall()


# S7 — transportista con mayor actividad en el último mes.
SQL_TRANSPORTISTA_ACTIVO = """
SELECT tr.codigo_transporte, tr.razon_social,
       count(DISTINCT i.codigo_ingreso) AS ingresos_trasladados,
       SUM(ri.cantidad)                 AS botellas_trasladadas
  FROM transportista tr
  JOIN ingreso i          ON i.codigo_transporte = tr.codigo_transporte
  JOIN renglon_ingreso ri ON ri.codigo_ingreso = i.codigo_ingreso
 WHERE i.fecha >= CURRENT_DATE - INTERVAL '1 month'
 GROUP BY tr.codigo_transporte, tr.razon_social
 ORDER BY ingresos_trasladados DESC
 FETCH FIRST 1 ROWS WITH TIES
"""


def transportista_activo(conn: Connection) -> list[dict]:
    return conn.execute(SQL_TRANSPORTISTA_ACTIVO).fetchall()


# Trazabilidad de un vino: ficha (S9) + de dónde vino (ingresos) + a dónde fue
# (transferencias a salas) + ventas por sala + historial de precios.
SQL_TRAZ_INGRESOS = """
SELECT i.codigo_ingreso, i.fecha, i.estado, t.razon_social AS transportista, ri.cantidad
  FROM renglon_ingreso ri
  JOIN ingreso i ON i.codigo_ingreso = ri.codigo_ingreso
  JOIN transportista t ON t.codigo_transporte = i.codigo_transporte
 WHERE ri.cod_vino = %s
 ORDER BY i.fecha DESC, i.codigo_ingreso DESC
 LIMIT 50
"""
SQL_TRAZ_TRANSFERENCIAS = """
SELECT t.nro_transferencia, t.fecha_confeccion, t.estado, t.id_sala, rt.cantidad
  FROM renglon_transferencia rt
  JOIN transferencia t ON t.nro_transferencia = rt.nro_transferencia
 WHERE rt.cod_vino = %s
 ORDER BY t.fecha_confeccion DESC, t.nro_transferencia DESC
 LIMIT 50
"""
SQL_TRAZ_VENTAS_SALA = """
SELECT c.id_sala, SUM(rc.cantidad) AS botellas_vendidas, SUM(rc.subtotal) AS importe,
       COALESCE(MAX(ss.cantidad), 0) AS stock_actual
  FROM renglon_comprobante rc
  JOIN comprobante c ON c.nro_comprobante = rc.nro_comprobante
  LEFT JOIN stock_sala ss ON ss.id_sala = c.id_sala AND ss.cod_vino = rc.cod_vino
 WHERE rc.cod_vino = %s
 GROUP BY c.id_sala
 ORDER BY botellas_vendidas DESC
"""
SQL_TRAZ_PRECIOS = """
SELECT precio_anterior, precio_nuevo, fecha_hora, usuario
  FROM auditoria_precio WHERE cod_vino = %s ORDER BY fecha_hora DESC
"""


def trazabilidad(conn: Connection, cod_vino: int) -> dict:
    return {
        "ingresos": conn.execute(SQL_TRAZ_INGRESOS, (cod_vino,)).fetchall(),
        "transferencias": conn.execute(SQL_TRAZ_TRANSFERENCIAS, (cod_vino,)).fetchall(),
        "ventas_por_sala": conn.execute(SQL_TRAZ_VENTAS_SALA, (cod_vino,)).fetchall(),
        "historial_precios": conn.execute(SQL_TRAZ_PRECIOS, (cod_vino,)).fetchall(),
    }
