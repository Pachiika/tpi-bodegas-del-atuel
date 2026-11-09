from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Connection

from ..db import get_db_connection
from ..repositorio import reportes as repo
from ..repositorio import vinos as repo_vinos

router = APIRouter(prefix="/reportes", tags=["Reportes"])


@router.get("/top-vinos", summary="S1: vinos más vendidos")
def top_vinos(limite: int = Query(10, ge=1, le=100), conn: Connection = Depends(get_db_connection)):
    return repo.top_vinos(conn, limite)


@router.get("/ventas-por-sala", summary="S8: monto vendido por sala (último trimestre por defecto)")
def ventas_por_sala(meses: int = Query(3, ge=1, le=36), conn: Connection = Depends(get_db_connection)):
    return repo.ventas_por_sala(conn, meses)


@router.get("/vinos-sin-stock", summary="S6: sin stock en la sala pero con stock en depósito")
def vinos_sin_stock(id_sala: int, conn: Connection = Depends(get_db_connection)):
    return repo.vinos_sin_stock(conn, id_sala)


@router.get("/transportista-activo", summary="S7: transportista con más actividad en el último mes")
def transportista_activo(conn: Connection = Depends(get_db_connection)):
    return repo.transportista_activo(conn)


@router.get("/trazabilidad/{cod_vino}", summary="Ficha del vino (S9) y sus movimientos")
def trazabilidad(cod_vino: int, conn: Connection = Depends(get_db_connection)):
    vino = repo_vinos.obtener(conn, cod_vino)
    if vino is None:
        raise HTTPException(404, f"No existe el vino {cod_vino}")
    return {"vino": vino, **repo.trazabilidad(conn, cod_vino)}
