"""Ventas: el comprobante completo (cabecera y renglones) en una transacción.

La API solo envía cliente, sala, vino y cantidad. Precio, descuento,
subtotales, total y descuento de stock los resuelven los triggers (RN-06,
RN-08, RN-09). Si un renglón no tiene stock, el trigger aborta y el ROLLBACK
deshace también la cabecera: no quedan datos a medias.
"""
from psycopg import Connection

SQL_INSERTAR_CABECERA = """
INSERT INTO comprobante (id_cliente, id_sala) VALUES (%s, %s) RETURNING nro_comprobante
"""
SQL_INSERTAR_RENGLON = """
INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad) VALUES (%s, %s, %s)
"""


def crear(conn: Connection, id_cliente: int, id_sala: int, renglones: list[dict]) -> int:
    with conn.transaction(), conn.cursor() as cur:
        nro = cur.execute(SQL_INSERTAR_CABECERA, (id_cliente, id_sala)).fetchone()["nro_comprobante"]
        cur.executemany(SQL_INSERTAR_RENGLON,
                        [(nro, r["cod_vino"], r["cantidad"]) for r in renglones])
    return nro


SQL_CABECERA = """
SELECT c.nro_comprobante, c.fecha, c.id_cliente, cl.nombre_o_razon_social AS cliente,
       cl.tipo_cliente, c.id_sala, c.subtotal, c.descuento, c.total
  FROM comprobante c JOIN cliente cl ON cl.id_cliente = c.id_cliente
 WHERE c.nro_comprobante = %s
"""
SQL_RENGLONES = """
SELECT rc.cod_vino, v.nombre, v.anada, v.volumen_ml, rc.cantidad, rc.precio_unitario,
       rc.descuento_aplicado, rc.subtotal
  FROM renglon_comprobante rc JOIN vino v ON v.cod_vino = rc.cod_vino
 WHERE rc.nro_comprobante = %s
 ORDER BY v.nombre
"""


def obtener(conn: Connection, nro: int) -> dict | None:
    cab = conn.execute(SQL_CABECERA, (nro,)).fetchone()
    if cab:
        cab["renglones"] = conn.execute(SQL_RENGLONES, (nro,)).fetchall()
    return cab


SQL_LISTAR = """
SELECT c.nro_comprobante, c.fecha, c.id_cliente, c.id_sala, c.total
  FROM comprobante c
 WHERE (%(id_cliente)s::int IS NULL OR c.id_cliente = %(id_cliente)s::int)
   AND (%(id_sala)s::int IS NULL OR c.id_sala = %(id_sala)s::int)
 ORDER BY c.fecha DESC, c.nro_comprobante DESC
 LIMIT %(limite)s OFFSET %(desplazamiento)s
"""


def listar(conn: Connection, *, id_cliente=None, id_sala=None, limite=20, desplazamiento=0):
    return conn.execute(SQL_LISTAR, {"id_cliente": id_cliente, "id_sala": id_sala,
                                     "limite": limite, "desplazamiento": desplazamiento}).fetchall()
