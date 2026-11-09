"""Clientes: una sola tabla para los tres tipos (socio, distribuidor, exportador)."""
from psycopg import Connection

SQL_LISTAR = """
SELECT cl.id_cliente, cl.nombre_o_razon_social, cl.tipo_doc, cl.nro_doc, cl.direccion,
       cl.cp_localidad, l.nombre AS localidad, cl.fecha_alta, cl.tipo_cliente, cl.descuento
  FROM cliente cl
  JOIN localidad l ON l.codigo_postal = cl.cp_localidad
 WHERE (%(tipo)s::text IS NULL OR cl.tipo_cliente = %(tipo)s::text)
   AND (%(q)s::text IS NULL OR cl.nombre_o_razon_social ILIKE '%%' || %(q)s::text || '%%'
                            OR cl.nro_doc = %(q)s::text)
 ORDER BY cl.id_cliente
 LIMIT %(limite)s OFFSET %(desplazamiento)s
"""
SQL_CONTAR = """
SELECT count(*) AS n FROM cliente cl
 WHERE (%(tipo)s::text IS NULL OR cl.tipo_cliente = %(tipo)s::text)
   AND (%(q)s::text IS NULL OR cl.nombre_o_razon_social ILIKE '%%' || %(q)s::text || '%%'
                            OR cl.nro_doc = %(q)s::text)
"""


def listar(conn: Connection, *, tipo=None, q=None, limite=20, desplazamiento=0):
    filtros = {"tipo": tipo, "q": q}
    filas = conn.execute(SQL_LISTAR, {**filtros, "limite": limite,
                                      "desplazamiento": desplazamiento}).fetchall()
    total = conn.execute(SQL_CONTAR, filtros).fetchone()["n"]
    return filas, total


SQL_OBTENER = """
SELECT id_cliente, nombre_o_razon_social, tipo_doc, nro_doc, direccion, cp_localidad,
       fecha_alta, tipo_cliente, descuento,
       zona_cobertura, nro_habilitacion, pais_destino_principal
  FROM cliente
 WHERE id_cliente = %s
"""
SQL_PERMISOS = """
SELECT codigo, fecha_emision, fecha_vencimiento
  FROM permiso_exportacion WHERE id_cliente = %s ORDER BY fecha_emision DESC
"""


def obtener(conn: Connection, id_cliente: int) -> dict | None:
    cl = conn.execute(SQL_OBTENER, (id_cliente,)).fetchone()
    if cl and cl["tipo_cliente"] == "exportador":
        cl["permisos"] = conn.execute(SQL_PERMISOS, (id_cliente,)).fetchall()
    return cl


# El descuento NO se envia: lo pone el trigger segun el tipo (RN-06).
# Que cada tipo tenga solo sus datos lo controla el CHECK ck_cliente_datos_tipo.
SQL_INSERTAR = """
INSERT INTO cliente (nombre_o_razon_social, tipo_doc, nro_doc, direccion, cp_localidad, tipo_cliente,
                     zona_cobertura, nro_habilitacion, pais_destino_principal)
VALUES (%(nombre_o_razon_social)s, %(tipo_doc)s, %(nro_doc)s, %(direccion)s, %(cp_localidad)s,
        %(tipo_cliente)s, %(zona_cobertura)s, %(nro_habilitacion)s, %(pais_destino_principal)s)
RETURNING id_cliente
"""


def crear(conn: Connection, datos: dict) -> int:
    return conn.execute(SQL_INSERTAR, datos).fetchone()["id_cliente"]


SQL_ACTUALIZAR = """
UPDATE cliente
   SET nombre_o_razon_social = %(nombre_o_razon_social)s, tipo_doc = %(tipo_doc)s,
       nro_doc = %(nro_doc)s, direccion = %(direccion)s, cp_localidad = %(cp_localidad)s,
       zona_cobertura = %(zona_cobertura)s, nro_habilitacion = %(nro_habilitacion)s,
       pais_destino_principal = %(pais_destino_principal)s
 WHERE id_cliente = %(id_cliente)s
"""


def actualizar(conn: Connection, id_cliente: int, datos: dict) -> bool:
    """El tipo de cliente no se cambia por esta via."""
    return conn.execute(SQL_ACTUALIZAR, {**datos, "id_cliente": id_cliente}).rowcount > 0


SQL_BORRAR = "DELETE FROM cliente WHERE id_cliente = %s"


def borrar(conn: Connection, id_cliente: int) -> bool:
    """Si tiene comprobantes, la FK con RESTRICT no deja borrarlo (23503 -> 409)."""
    return conn.execute(SQL_BORRAR, (id_cliente,)).rowcount > 0
