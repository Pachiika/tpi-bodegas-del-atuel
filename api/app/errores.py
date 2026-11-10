# Mapeo centralizado de SQLSTATE de PostgreSQL a códigos HTTP.
import logging

import psycopg
from fastapi import Request
from fastapi.responses import JSONResponse
from psycopg_pool import PoolTimeout

log = logging.getLogger("bodegas.errores")

# SQLSTATE -> (código HTTP)
TRADUCCION = {
    "23505": (409, "unique_violation"),
    "23503": (409, "foreign_key_violation"),
    "23001": (409, "restrict_violation"),      
    "23514": (422, "check_violation"),
    "23502": (422, "not_null_violation"),
    "P0001": (409, "regla_de_negocio"),
    "22P02": (400, "formato_invalido"),
    "22003": (400, "valor_fuera_de_rango"),
    "22007": (400, "fecha_invalida"),
    "22008": (400, "fecha_fuera_de_rango"),
    "40001": (503, "serialization_failure"),
    "40P01": (503, "deadlock_detected"),
    "55P03": (503, "lock_not_available"),
    "42501": (403, "permiso_denegado"),
}


def traducir(exc: psycopg.Error) -> tuple[int, dict]:
    sqlstate = exc.sqlstate or ""
    status, nombre = TRADUCCION.get(sqlstate, (500, "error_de_base"))
    diag = exc.diag
    cuerpo = {
        "error": nombre,
        "sqlstate": sqlstate,
        "mensaje": diag.message_primary or str(exc),
        "detalle": diag.message_detail,
        "restriccion": diag.constraint_name,
        "tabla": diag.table_name,
    }
    if status == 500:
        # No se filtran detalles internos al cliente; quedan en el log.
        log.exception("Error de base no previsto", exc_info=exc)
        cuerpo.update(mensaje="Error interno de la base de datos", detalle=None)
    return status, cuerpo


async def manejar_error_postgres(request: Request, exc: psycopg.Error) -> JSONResponse:
    status, cuerpo = traducir(exc)
    headers = {"Retry-After": "1"} if status == 503 else None
    if status == 503:
        cuerpo["sugerencia"] = "Conflicto de concurrencia: reintentar la operación."
    return JSONResponse(status_code=status, content=cuerpo, headers=headers)


async def manejar_pool_agotado(request: Request, exc: PoolTimeout) -> JSONResponse:
    return JSONResponse(
        status_code=503, headers={"Retry-After": "2"},
        content={"error": "sin_conexiones", "mensaje": "La base no está disponible o el pool está agotado."},
    )
