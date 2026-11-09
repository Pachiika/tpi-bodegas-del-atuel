from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from psycopg import Connection

from ..db import get_db_connection
from ..esquemas import ComprobanteEntrada
from ..paginacion import Paginacion, paginacion, respuesta
from ..repositorio import comprobantes as repo

router = APIRouter(prefix="/comprobantes", tags=["Comprobantes"])


@router.post("", status_code=status.HTTP_201_CREATED,
             summary="Venta completa en una transacción (409 si no hay stock, RN-09)")
def crear(c: ComprobanteEntrada, conn: Connection = Depends(get_db_connection)):
    nro = repo.crear(conn, c.id_cliente, c.id_sala, [r.model_dump() for r in c.renglones])
    return repo.obtener(conn, nro)  # importes calculados por la base


@router.get("", summary="Listado (filtros por cliente y sala)")
def listar(id_cliente: Optional[int] = None, id_sala: Optional[int] = None,
           p: Paginacion = Depends(paginacion), conn: Connection = Depends(get_db_connection)):
    return respuesta(repo.listar(conn, id_cliente=id_cliente, id_sala=id_sala,
                                 limite=p.tamanio, desplazamiento=p.desplazamiento), p)


@router.get("/{nro}", summary="Cabecera y renglones")
def obtener(nro: int, conn: Connection = Depends(get_db_connection)):
    comp = repo.obtener(conn, nro)
    if comp is None:
        raise HTTPException(404, f"No existe el comprobante {nro}")
    return comp
