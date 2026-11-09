from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from psycopg import Connection

from ..db import get_db_connection
from ..esquemas import VinoEntrada, VinoModificacion
from ..paginacion import Paginacion, paginacion, respuesta
from ..repositorio import vinos as repo

router = APIRouter(prefix="/vinos", tags=["Vinos"])


@router.get("", summary="Catálogo con filtros y paginación")
def listar(tipo: Optional[str] = Query(None, description="tinto, blanco, rosado o espumante"),
           cepa: Optional[str] = Query(None, description="id o nombre de la cepa"),
           bodega: Optional[str] = Query(None, description="CUIT o parte de la razón social"),
           anada: Optional[int] = None,
           nombre: Optional[str] = Query(None, description="comienzo del nombre"),
           p: Paginacion = Depends(paginacion), conn: Connection = Depends(get_db_connection)):
    datos, total = repo.listar(conn, tipo=tipo, cepa=cepa, bodega=bodega, anada=anada,
                               nombre=nombre, limite=p.tamanio, desplazamiento=p.desplazamiento)
    return respuesta(datos, p, total)


@router.get("/{cod_vino}", summary="Ficha: composición, maridajes y stock")
def obtener(cod_vino: int, conn: Connection = Depends(get_db_connection)):
    vino = repo.obtener(conn, cod_vino)
    if vino is None:
        raise HTTPException(404, f"No existe el vino {cod_vino}")
    return vino


@router.post("", status_code=status.HTTP_201_CREATED, summary="Alta con composición (RN-05)")
def crear(v: VinoEntrada, conn: Connection = Depends(get_db_connection)):
    datos = v.model_dump(exclude={"composicion", "maridajes"})
    cod = repo.crear(conn, datos, [c.model_dump() for c in v.composicion], v.maridajes)
    return repo.obtener(conn, cod)


@router.put("/{cod_vino}", summary="Modificación (el cambio de precio queda auditado, RN-13)")
def actualizar(cod_vino: int, v: VinoModificacion, conn: Connection = Depends(get_db_connection)):
    datos = v.model_dump(exclude={"composicion", "maridajes"})
    comp = [c.model_dump() for c in v.composicion] if v.composicion is not None else None
    if not repo.actualizar(conn, cod_vino, datos, comp, v.maridajes):
        raise HTTPException(404, f"No existe el vino {cod_vino}")
    return repo.obtener(conn, cod_vino)


@router.delete("/{cod_vino}", status_code=status.HTTP_204_NO_CONTENT,
               summary="Baja (RN-14: falla con 409 si tiene movimientos)")
def borrar(cod_vino: int, conn: Connection = Depends(get_db_connection)):
    if not repo.borrar(conn, cod_vino):
        raise HTTPException(404, f"No existe el vino {cod_vino}")


@router.get("/{cod_vino}/auditoria-precio", summary="Historial de cambios de precio")
def auditoria(cod_vino: int, conn: Connection = Depends(get_db_connection)):
    return repo.auditoria_precio(conn, cod_vino)
