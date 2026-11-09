"""Vinos: catálogo, ficha, alta con composición, modificación y baja."""
from psycopg import Connection

# Filtros opcionales: cada uno se anula cuando el parámetro es NULL. El texto
# SQL es fijo (constantes del módulo); solo cambian los valores de los parámetros.
_FROM_WHERE_CATALOGO = """
  FROM vino v
  JOIN bodega b ON b.cuit = v.cuit_bodega
 WHERE (%(tipo)s::text IS NULL OR v.tipo = %(tipo)s::text)
   AND (%(anada)s::smallint IS NULL OR v.anada = %(anada)s::smallint)
   AND (%(bodega)s::text IS NULL OR v.cuit_bodega = %(bodega)s::text
                                 OR b.razon_social ILIKE '%%' || %(bodega)s::text || '%%')
   AND (%(cepa)s::text IS NULL OR EXISTS (
          SELECT 1 FROM composicion_vino cv JOIN cepa c ON c.id_cepa = cv.id_cepa
           WHERE cv.cod_vino = v.cod_vino
             AND (c.id_cepa::text = %(cepa)s::text OR lower(c.nombre) = lower(%(cepa)s::text))))
   AND (%(nombre)s::text IS NULL OR lower(v.nombre) LIKE lower(%(nombre)s::text) || '%%')
"""
SQL_CATALOGO = """
SELECT v.cod_vino, v.nombre, v.tipo, v.anada, v.volumen_ml, v.graduacion, v.precio,
       v.cuit_bodega, b.razon_social AS bodega
""" + _FROM_WHERE_CATALOGO + """
 ORDER BY v.nombre, v.anada, v.cod_vino
 LIMIT %(limite)s OFFSET %(desplazamiento)s
"""
SQL_CONTAR_CATALOGO = "SELECT count(*) AS n" + _FROM_WHERE_CATALOGO


def listar(conn: Connection, *, tipo=None, anada=None, bodega=None, cepa=None,
           nombre=None, limite=20, desplazamiento=0) -> tuple[list[dict], int]:
    filtros = {"tipo": tipo, "anada": anada, "bodega": bodega, "cepa": cepa, "nombre": nombre}
    filas = conn.execute(SQL_CATALOGO, {**filtros, "limite": limite,
                                        "desplazamiento": desplazamiento}).fetchall()
    total = conn.execute(SQL_CONTAR_CATALOGO, filtros).fetchone()["n"]
    return filas, total


SQL_FICHA = """
SELECT v.cod_vino, v.nombre, v.tipo, v.anada, v.volumen_ml, v.graduacion, v.precio,
       v.cuit_bodega, b.razon_social AS bodega,
       st.stock_deposito, st.stock_en_salas, st.stock_total
  FROM vino v
  JOIN bodega b ON b.cuit = v.cuit_bodega
  JOIN vw_stock_total_vino st ON st.cod_vino = v.cod_vino
 WHERE v.cod_vino = %s
"""
SQL_COMPOSICION = """
SELECT c.id_cepa, c.nombre, c.tipo, cv.porcentaje
  FROM composicion_vino cv JOIN cepa c ON c.id_cepa = cv.id_cepa
 WHERE cv.cod_vino = %s
 ORDER BY cv.porcentaje DESC, c.nombre
"""
SQL_MARIDAJES = """
SELECT m.id_maridaje, m.nombre, m.temperatura_servicio
  FROM vino_maridaje vm JOIN maridaje m ON m.id_maridaje = vm.id_maridaje
 WHERE vm.cod_vino = %s
 ORDER BY m.nombre
"""


def obtener(conn: Connection, cod_vino: int) -> dict | None:
    vino = conn.execute(SQL_FICHA, (cod_vino,)).fetchone()
    if vino is None:
        return None
    vino["composicion"] = conn.execute(SQL_COMPOSICION, (cod_vino,)).fetchall()
    vino["maridajes"] = conn.execute(SQL_MARIDAJES, (cod_vino,)).fetchall()
    return vino


SQL_INSERTAR = """
INSERT INTO vino (nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
VALUES (%(nombre)s, %(tipo)s, %(anada)s, %(volumen_ml)s, %(graduacion)s, %(precio)s, %(cuit_bodega)s)
RETURNING cod_vino
"""
SQL_ACTUALIZAR = """
UPDATE vino
   SET nombre = %(nombre)s, tipo = %(tipo)s, anada = %(anada)s, volumen_ml = %(volumen_ml)s,
       graduacion = %(graduacion)s, precio = %(precio)s, cuit_bodega = %(cuit_bodega)s
 WHERE cod_vino = %(cod_vino)s
"""
SQL_BORRAR_COMPOSICION = "DELETE FROM composicion_vino WHERE cod_vino = %s"
SQL_INSERTAR_COMPOSICION = "INSERT INTO composicion_vino (cod_vino, id_cepa, porcentaje) VALUES (%s, %s, %s)"
SQL_BORRAR_MARIDAJES = "DELETE FROM vino_maridaje WHERE cod_vino = %s"
SQL_INSERTAR_MARIDAJE = "INSERT INTO vino_maridaje (cod_vino, id_maridaje) VALUES (%s, %s)"
SQL_BORRAR = "DELETE FROM vino WHERE cod_vino = %s"


def _guardar_detalle(cur, cod_vino: int, composicion: list[dict], maridajes: list[int] | None):
    cur.execute(SQL_BORRAR_COMPOSICION, (cod_vino,))
    cur.executemany(SQL_INSERTAR_COMPOSICION,
                    [(cod_vino, c["id_cepa"], c["porcentaje"]) for c in composicion])
    if maridajes is not None:
        cur.execute(SQL_BORRAR_MARIDAJES, (cod_vino,))
        cur.executemany(SQL_INSERTAR_MARIDAJE, [(cod_vino, m) for m in maridajes])


def crear(conn: Connection, datos: dict, composicion: list[dict], maridajes: list[int]) -> int:
    """Vino + composición + maridajes en una sola transacción.
    La suma de porcentajes = 100 (RN-05) la controla un constraint trigger
    diferido: si no da 100, el COMMIT falla y no queda nada guardado."""
    with conn.transaction(), conn.cursor() as cur:
        cod = cur.execute(SQL_INSERTAR, datos).fetchone()["cod_vino"]
        _guardar_detalle(cur, cod, composicion, maridajes)
    return cod


def actualizar(conn: Connection, cod_vino: int, datos: dict,
               composicion: list[dict] | None, maridajes: list[int] | None) -> bool:
    """Si cambia el precio, el trigger de auditoría (RN-13) registra el cambio."""
    with conn.transaction(), conn.cursor() as cur:
        cur.execute(SQL_ACTUALIZAR, {**datos, "cod_vino": cod_vino})
        if cur.rowcount == 0:
            return False
        if composicion is not None:
            _guardar_detalle(cur, cod_vino, composicion, maridajes)
        elif maridajes is not None:
            cur.execute(SQL_BORRAR_MARIDAJES, (cod_vino,))
            cur.executemany(SQL_INSERTAR_MARIDAJE, [(cod_vino, m) for m in maridajes])
    return True


def borrar(conn: Connection, cod_vino: int) -> bool:
    """RN-14: si el vino tiene ventas, stock o movimientos, la FK con
    ON DELETE RESTRICT lo impide (23503 -> 409)."""
    return conn.execute(SQL_BORRAR, (cod_vino,)).rowcount > 0


SQL_AUDITORIA = """
SELECT id_auditoria, precio_anterior, precio_nuevo, fecha_hora, usuario
  FROM auditoria_precio WHERE cod_vino = %s ORDER BY fecha_hora DESC, id_auditoria DESC
"""


def auditoria_precio(conn: Connection, cod_vino: int) -> list[dict]:
    return conn.execute(SQL_AUDITORIA, (cod_vino,)).fetchall()
