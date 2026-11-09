from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from psycopg import Connection

from ..db import get_db_connection
from ..esquemas import ClienteEntrada, ClienteModificacion
from ..paginacion import Paginacion, paginacion, respuesta
from ..repositorio import clientes as repo

router = APIRouter(prefix="/clientes", tags=["Clientes"])


@router.get("", summary="Listado paginado")
def listar(tipo: Optional[str] = Query(None, description="socio, distribuidor o exportador"),
           q: Optional[str] = Query(None, description="parte del nombre o número de documento"),
           p: Paginacion = Depends(paginacion), conn: Connection = Depends(get_db_connection)):
    datos, total = repo.listar(conn, tipo=tipo, q=q, limite=p.tamanio, desplazamiento=p.desplazamiento)
    return respuesta(datos, p, total)


@router.get("/{id_cliente}", summary="Detalle con los datos propios de su tipo")
def obtener(id_cliente: int, conn: Connection = Depends(get_db_connection)):
    cl = repo.obtener(conn, id_cliente)
    if cl is None:
        raise HTTPException(404, f"No existe el cliente {id_cliente}")
    return cl


@router.post("", status_code=status.HTTP_201_CREATED,
             summary="Alta (el descuento lo asigna la base según el tipo, RN-06)")
def crear(c: ClienteEntrada, conn: Connection = Depends(get_db_connection)):
    return repo.obtener(conn, repo.crear(conn, c.model_dump()))


@router.put("/{id_cliente}", summary="Modificación de datos (el tipo no cambia)")
def actualizar(id_cliente: int, c: ClienteModificacion, conn: Connection = Depends(get_db_connection)):
    if not repo.actualizar(conn, id_cliente, c.model_dump()):
        raise HTTPException(404, f"No existe el cliente {id_cliente}")
    return repo.obtener(conn, id_cliente)


@router.delete("/{id_cliente}", status_code=status.HTTP_204_NO_CONTENT,
               summary="Baja (409 si tiene comprobantes)")
def borrar(id_cliente: int, conn: Connection = Depends(get_db_connection)):
    if not repo.borrar(conn, id_cliente):
        raise HTTPException(404, f"No existe el cliente {id_cliente}")
