from fastapi import APIRouter, Depends
from psycopg import Connection

from ..db import get_db_connection
from ..repositorio import catalogos as repo

router = APIRouter(tags=["Catálogos"])


@router.get("/salud", summary="Verifica que la API llega a la base (y con qué rol)")
def salud(conn: Connection = Depends(get_db_connection)):
    return {"estado": "ok", **repo.salud(conn)}


@router.get("/salas")
def salas(conn: Connection = Depends(get_db_connection)):
    return repo.salas(conn)


@router.get("/cepas")
def cepas(conn: Connection = Depends(get_db_connection)):
    return repo.cepas(conn)


@router.get("/bodegas")
def bodegas(conn: Connection = Depends(get_db_connection)):
    return repo.bodegas(conn)


@router.get("/maridajes")
def maridajes(conn: Connection = Depends(get_db_connection)):
    return repo.maridajes(conn)


@router.get("/transportistas")
def transportistas(conn: Connection = Depends(get_db_connection)):
    return repo.transportistas(conn)


@router.get("/localidades")
def localidades(conn: Connection = Depends(get_db_connection)):
    return repo.localidades(conn)
