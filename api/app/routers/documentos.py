"""Transferencias e ingresos: mismo circuito de estados."""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from psycopg import Connection

from ..db import get_db_connection
from ..esquemas import IngresoEntrada, RenglonDocumento, TransferenciaEntrada
from ..paginacion import Paginacion, paginacion, respuesta
from ..repositorio import documentos as repo

transferencias = APIRouter(prefix="/transferencias", tags=["Transferencias"])
ingresos = APIRouter(prefix="/ingresos", tags=["Ingresos"])


def _transferencia(conn, nro):
    t = repo.obtener_transferencia(conn, nro)
    if t is None:
        raise HTTPException(404, f"No existe la transferencia {nro}")
    return t


def _ingreso(conn, codigo):
    i = repo.obtener_ingreso(conn, codigo)
    if i is None:
        raise HTTPException(404, f"No existe el ingreso {codigo}")
    return i


# ------------------------------------------------------------------ transferencias
@transferencias.get("", summary="Listado (filtros por estado y sala)")
def listar_transferencias(estado: Optional[str] = None, id_sala: Optional[int] = None,
                          p: Paginacion = Depends(paginacion), conn: Connection = Depends(get_db_connection)):
    return respuesta(repo.listar_transferencias(conn, estado=estado, id_sala=id_sala,
                                                limite=p.tamanio, desplazamiento=p.desplazamiento), p)


@transferencias.post("", status_code=status.HTTP_201_CREATED, summary="Alta (nace en confección)")
def crear_transferencia(t: TransferenciaEntrada, conn: Connection = Depends(get_db_connection)):
    return _transferencia(conn, repo.crear_transferencia(conn, t.id_sala))


@transferencias.get("/{nro}", summary="Detalle con renglones")
def obtener_transferencia(nro: int, conn: Connection = Depends(get_db_connection)):
    return _transferencia(conn, nro)


@transferencias.post("/{nro}/renglones", summary="Agregar renglón (solo en confección, RN-12)")
def agregar_renglon_transferencia(nro: int, r: RenglonDocumento, conn: Connection = Depends(get_db_connection)):
    _transferencia(conn, nro)
    repo.agregar_renglon_transferencia(conn, nro, r.cod_vino, r.cantidad)
    return _transferencia(conn, nro)


@transferencias.delete("/{nro}/renglones/{cod_vino}", summary="Quitar renglón (solo en confección)")
def quitar_renglon_transferencia(nro: int, cod_vino: int, conn: Connection = Depends(get_db_connection)):
    _transferencia(conn, nro)
    repo.quitar_renglon_transferencia(conn, nro, cod_vino)
    return _transferencia(conn, nro)


@transferencias.post("/{nro}/terminar", summary="en_confeccion -> terminado")
def terminar_transferencia(nro: int, conn: Connection = Depends(get_db_connection)):
    if not repo.terminar_transferencia(conn, nro):
        raise HTTPException(404, f"No existe la transferencia {nro}")
    return _transferencia(conn, nro)


@transferencias.post("/{nro}/procesar", summary="terminado -> procesado (invoca sp_procesar_transferencia)")
def procesar_transferencia(nro: int, conn: Connection = Depends(get_db_connection)):
    _transferencia(conn, nro)
    repo.procesar_transferencia(conn, nro)
    return _transferencia(conn, nro)


# ------------------------------------------------------------------------ ingresos
@ingresos.get("", summary="Listado (filtro por estado)")
def listar_ingresos(estado: Optional[str] = None, p: Paginacion = Depends(paginacion),
                    conn: Connection = Depends(get_db_connection)):
    return respuesta(repo.listar_ingresos(conn, estado=estado, limite=p.tamanio,
                                          desplazamiento=p.desplazamiento), p)


@ingresos.post("", status_code=status.HTTP_201_CREATED, summary="Alta (nace en confección)")
def crear_ingreso(i: IngresoEntrada, conn: Connection = Depends(get_db_connection)):
    return _ingreso(conn, repo.crear_ingreso(conn, i.codigo_transporte, i.cuit_bodega))


@ingresos.get("/{codigo}", summary="Detalle con renglones")
def obtener_ingreso(codigo: int, conn: Connection = Depends(get_db_connection)):
    return _ingreso(conn, codigo)


@ingresos.post("/{codigo}/renglones", summary="Agregar renglón (solo en confección, RN-12)")
def agregar_renglon_ingreso(codigo: int, r: RenglonDocumento, conn: Connection = Depends(get_db_connection)):
    _ingreso(conn, codigo)
    repo.agregar_renglon_ingreso(conn, codigo, r.cod_vino, r.cantidad)
    return _ingreso(conn, codigo)


@ingresos.post("/{codigo}/terminar", summary="en_confeccion -> terminado")
def terminar_ingreso(codigo: int, conn: Connection = Depends(get_db_connection)):
    if not repo.terminar_ingreso(conn, codigo):
        raise HTTPException(404, f"No existe el ingreso {codigo}")
    return _ingreso(conn, codigo)


@ingresos.post("/{codigo}/procesar", summary="terminado -> procesado (invoca sp_procesar_ingreso)")
def procesar_ingreso(codigo: int, conn: Connection = Depends(get_db_connection)):
    _ingreso(conn, codigo)
    repo.procesar_ingreso(conn, codigo)
    return _ingreso(conn, codigo)
