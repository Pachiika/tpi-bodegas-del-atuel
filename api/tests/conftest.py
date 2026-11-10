"""Tests de integración con DB real en Docker. Ejecutar: docker compose exec api pytest -v"""
import random
import string

import psycopg
import pytest
from fastapi.testclient import TestClient
from psycopg.rows import dict_row

from app.db import DSN
from app.main import app


def _sufijo(n=6):
    return "".join(random.choices(string.digits, k=n))


@pytest.fixture(scope="session")
def cliente_http():
    with TestClient(app) as c:
        yield c


@pytest.fixture(scope="session")
def datos():
    """Datos base propios de la prueba, creados directamente en la base."""
    s = _sufijo()
    conn = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
    d = {"sufijo": s}
    d["cp"] = "T" + s
    conn.execute("INSERT INTO localidad (codigo_postal, nombre, provincia, encargado_regional) "
                 "VALUES (%s, %s, 'Mendoza', 'Encargado de prueba')", (d["cp"], "Localidad prueba " + s))
    d["id_sala"] = conn.execute(
        "INSERT INTO sala_venta (calle, numero, dia_cierre, cp_localidad) "
        "VALUES ('Calle de prueba', %s, 'lunes', %s) RETURNING id_sala", (s[:4], d["cp"])).fetchone()["id_sala"]
    d["cuit_bodega"] = "309" + s + "01"
    conn.execute("INSERT INTO bodega (cuit, razon_social, domicilio) VALUES (%s, %s, 'Ruta 143')",
                 (d["cuit_bodega"], "Bodega Prueba " + s))
    d["cepa1"] = conn.execute("INSERT INTO cepa (nombre, tipo) VALUES (%s, 'tinta') RETURNING id_cepa",
                              ("CepaA " + s,)).fetchone()["id_cepa"]
    d["cepa2"] = conn.execute("INSERT INTO cepa (nombre, tipo) VALUES (%s, 'tinta') RETURNING id_cepa",
                              ("CepaB " + s,)).fetchone()["id_cepa"]
    d["transporte"] = conn.execute(
        "INSERT INTO transportista (razon_social, cuit, email, telefono, domicilio) "
        "VALUES (%s, %s, 'prueba@transporte.com', '260-000000', 'Ruta 40') RETURNING codigo_transporte",
        ("Transporte Prueba " + s, "307" + s + "02")).fetchone()["codigo_transporte"]
    yield d
    # Limpieza (orden inverso a las FK). Lo que tenga auditoría de precio o
    # ventas queda, porque app_rw no puede borrar la auditoría (es a propósito).
    for sql, params in [
        ("DELETE FROM comprobante WHERE id_sala = %s", (d["id_sala"],)),
        ("DELETE FROM transferencia WHERE id_sala = %s", (d["id_sala"],)),
        ("DELETE FROM ingreso WHERE cuit_bodega = %s", (d["cuit_bodega"],)),
        ("DELETE FROM stock_sala WHERE id_sala = %s", (d["id_sala"],)),
        ("DELETE FROM stock_deposito WHERE cod_vino IN (SELECT cod_vino FROM vino WHERE cuit_bodega = %s)",
         (d["cuit_bodega"],)),
        ("DELETE FROM cliente WHERE cp_localidad = %s", (d["cp"],)),
        ("DELETE FROM vino WHERE cuit_bodega = %s AND cod_vino NOT IN (SELECT cod_vino FROM auditoria_precio)",
         (d["cuit_bodega"],)),
    ]:
        try:
            conn.execute(sql, params)
        except psycopg.Error:
            pass
    conn.close()


@pytest.fixture(scope="session")
def conexion():
    conn = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
    yield conn
    conn.close()
