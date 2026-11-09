"""Listas chicas que usa el front para armar los combos."""
from psycopg import Connection

SQL_SALAS = """
SELECT s.id_sala, l.nombre || ' - ' || s.calle || ' ' || s.numero AS nombre, s.dia_cierre
  FROM sala_venta s JOIN localidad l ON l.codigo_postal = s.cp_localidad
 ORDER BY s.id_sala
"""
SQL_CEPAS = "SELECT id_cepa, nombre, tipo FROM cepa ORDER BY nombre"
SQL_BODEGAS = "SELECT cuit, razon_social FROM bodega ORDER BY razon_social"
SQL_MARIDAJES = "SELECT id_maridaje, nombre, temperatura_servicio FROM maridaje ORDER BY nombre"
SQL_TRANSPORTISTAS = "SELECT codigo_transporte, razon_social FROM transportista ORDER BY razon_social"
SQL_LOCALIDADES = "SELECT codigo_postal, nombre FROM localidad ORDER BY nombre"
SQL_SALUD = """
SELECT current_user AS usuario, current_database() AS base,
       (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) AS es_superusuario,
       pg_catalog.has_table_privilege('auditoria_precio', 'INSERT') AS puede_escribir_auditoria,
       split_part(version(), ' ', 2) AS version_postgres, now() AS hora_servidor
"""


def salas(conn: Connection):
    return conn.execute(SQL_SALAS).fetchall()


def cepas(conn: Connection):
    return conn.execute(SQL_CEPAS).fetchall()


def bodegas(conn: Connection):
    return conn.execute(SQL_BODEGAS).fetchall()


def maridajes(conn: Connection):
    return conn.execute(SQL_MARIDAJES).fetchall()


def transportistas(conn: Connection):
    return conn.execute(SQL_TRANSPORTISTAS).fetchall()


def localidades(conn: Connection):
    return conn.execute(SQL_LOCALIDADES).fetchall()


def salud(conn: Connection):
    return conn.execute(SQL_SALUD).fetchone()
