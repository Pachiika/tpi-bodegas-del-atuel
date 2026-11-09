"""Transferencias (depósito -> sala) e ingresos (bodega -> depósito).

Circuito: en_confeccion -> terminado -> procesado (RN-10, RN-11, RN-12).
- Los renglones solo se cargan en confección (lo controla un trigger).
- 'terminar' es un UPDATE de estado; el trigger exige que haya renglones.
- 'procesar' invoca el procedimiento almacenado, que mueve el stock dentro de
  la misma transacción. La API no toca stock ni estados por su cuenta.
"""
from psycopg import Connection

# ----------------------------------------------------------------- transferencias
SQL_TRANSF_CREAR = "INSERT INTO transferencia (id_sala) VALUES (%s) RETURNING nro_transferencia"
SQL_TRANSF_RENGLON = """
INSERT INTO renglon_transferencia (nro_transferencia, cod_vino, cantidad) VALUES (%s, %s, %s)
ON CONFLICT (nro_transferencia, cod_vino)
DO UPDATE SET cantidad = renglon_transferencia.cantidad + EXCLUDED.cantidad
"""
SQL_TRANSF_QUITAR_RENGLON = "DELETE FROM renglon_transferencia WHERE nro_transferencia = %s AND cod_vino = %s"
SQL_TRANSF_TERMINAR = """
UPDATE transferencia SET estado = 'terminado' WHERE nro_transferencia = %s RETURNING estado
"""
SQL_TRANSF_PROCESAR = "CALL sp_procesar_transferencia(%s)"
SQL_TRANSF_CABECERA = """
SELECT t.nro_transferencia, t.id_sala, l.nombre || ' - ' || s.calle || ' ' || s.numero AS sala,
       t.fecha_confeccion, t.estado
  FROM transferencia t
  JOIN sala_venta s ON s.id_sala = t.id_sala
  JOIN localidad  l ON l.codigo_postal = s.cp_localidad
 WHERE t.nro_transferencia = %s
"""
SQL_TRANSF_RENGLONES = """
SELECT rt.cod_vino, v.nombre, v.anada, v.volumen_ml, rt.cantidad,
       COALESCE(sd.cantidad, 0) AS stock_deposito
  FROM renglon_transferencia rt
  JOIN vino v ON v.cod_vino = rt.cod_vino
  LEFT JOIN stock_deposito sd ON sd.cod_vino = rt.cod_vino
 WHERE rt.nro_transferencia = %s
 ORDER BY v.nombre
"""
SQL_TRANSF_LISTAR = """
SELECT t.nro_transferencia, t.id_sala, t.fecha_confeccion, t.estado,
       (SELECT COALESCE(SUM(cantidad), 0) FROM renglon_transferencia r
         WHERE r.nro_transferencia = t.nro_transferencia) AS botellas
  FROM transferencia t
 WHERE (%(estado)s::estado_transferencia IS NULL OR t.estado = %(estado)s::estado_transferencia)
   AND (%(id_sala)s::int IS NULL OR t.id_sala = %(id_sala)s::int)
 ORDER BY t.nro_transferencia DESC
 LIMIT %(limite)s OFFSET %(desplazamiento)s
"""


def crear_transferencia(conn: Connection, id_sala: int) -> int:
    return conn.execute(SQL_TRANSF_CREAR, (id_sala,)).fetchone()["nro_transferencia"]


def agregar_renglon_transferencia(conn: Connection, nro: int, cod_vino: int, cantidad: int) -> None:
    conn.execute(SQL_TRANSF_RENGLON, (nro, cod_vino, cantidad))


def quitar_renglon_transferencia(conn: Connection, nro: int, cod_vino: int) -> bool:
    return conn.execute(SQL_TRANSF_QUITAR_RENGLON, (nro, cod_vino)).rowcount > 0


def terminar_transferencia(conn: Connection, nro: int) -> bool:
    return conn.execute(SQL_TRANSF_TERMINAR, (nro,)).fetchone() is not None


def procesar_transferencia(conn: Connection, nro: int) -> None:
    # En autocommit, CALL corre en su propia transacción: o se mueve todo el
    # stock y cambia el estado, o (stock insuficiente) no cambia nada.
    conn.execute(SQL_TRANSF_PROCESAR, (nro,))


def obtener_transferencia(conn: Connection, nro: int) -> dict | None:
    t = conn.execute(SQL_TRANSF_CABECERA, (nro,)).fetchone()
    if t:
        t["renglones"] = conn.execute(SQL_TRANSF_RENGLONES, (nro,)).fetchall()
    return t


def listar_transferencias(conn: Connection, *, estado=None, id_sala=None, limite=20, desplazamiento=0):
    return conn.execute(SQL_TRANSF_LISTAR, {"estado": estado, "id_sala": id_sala,
                                            "limite": limite, "desplazamiento": desplazamiento}).fetchall()


# ----------------------------------------------------------------------- ingresos
SQL_ING_CREAR = """
INSERT INTO ingreso (codigo_transporte, cuit_bodega) VALUES (%s, %s) RETURNING codigo_ingreso
"""
SQL_ING_RENGLON = """
INSERT INTO renglon_ingreso (codigo_ingreso, cod_vino, cantidad) VALUES (%s, %s, %s)
ON CONFLICT (codigo_ingreso, cod_vino)
DO UPDATE SET cantidad = renglon_ingreso.cantidad + EXCLUDED.cantidad
"""
SQL_ING_TERMINAR = "UPDATE ingreso SET estado = 'terminado' WHERE codigo_ingreso = %s RETURNING estado"
SQL_ING_PROCESAR = "CALL sp_procesar_ingreso(%s)"
SQL_ING_CABECERA = """
SELECT i.codigo_ingreso, i.fecha, i.estado, i.codigo_transporte, t.razon_social AS transportista,
       i.cuit_bodega, b.razon_social AS bodega
  FROM ingreso i
  JOIN transportista t ON t.codigo_transporte = i.codigo_transporte
  JOIN bodega b ON b.cuit = i.cuit_bodega
 WHERE i.codigo_ingreso = %s
"""
SQL_ING_RENGLONES = """
SELECT ri.cod_vino, v.nombre, v.anada, v.volumen_ml, ri.cantidad
  FROM renglon_ingreso ri JOIN vino v ON v.cod_vino = ri.cod_vino
 WHERE ri.codigo_ingreso = %s
 ORDER BY v.nombre
"""
SQL_ING_LISTAR = """
SELECT i.codigo_ingreso, i.fecha, i.estado, i.codigo_transporte, i.cuit_bodega
  FROM ingreso i
 WHERE (%(estado)s::estado_ingreso IS NULL OR i.estado = %(estado)s::estado_ingreso)
 ORDER BY i.codigo_ingreso DESC
 LIMIT %(limite)s OFFSET %(desplazamiento)s
"""


def crear_ingreso(conn: Connection, codigo_transporte: int, cuit_bodega: str) -> int:
    return conn.execute(SQL_ING_CREAR, (codigo_transporte, cuit_bodega)).fetchone()["codigo_ingreso"]


def agregar_renglon_ingreso(conn: Connection, codigo: int, cod_vino: int, cantidad: int) -> None:
    conn.execute(SQL_ING_RENGLON, (codigo, cod_vino, cantidad))


def terminar_ingreso(conn: Connection, codigo: int) -> bool:
    return conn.execute(SQL_ING_TERMINAR, (codigo,)).fetchone() is not None


def procesar_ingreso(conn: Connection, codigo: int) -> None:
    conn.execute(SQL_ING_PROCESAR, (codigo,))


def obtener_ingreso(conn: Connection, codigo: int) -> dict | None:
    i = conn.execute(SQL_ING_CABECERA, (codigo,)).fetchone()
    if i:
        i["renglones"] = conn.execute(SQL_ING_RENGLONES, (codigo,)).fetchall()
    return i


def listar_ingresos(conn: Connection, *, estado=None, limite=20, desplazamiento=0):
    return conn.execute(SQL_ING_LISTAR, {"estado": estado, "limite": limite,
                                         "desplazamiento": desplazamiento}).fetchall()
