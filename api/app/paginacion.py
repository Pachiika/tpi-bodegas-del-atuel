from dataclasses import dataclass

from fastapi import Query

from .config import PAGINA_MAX


@dataclass
class Paginacion:
    pagina: int
    tamanio: int

    @property
    def desplazamiento(self) -> int:
        return (self.pagina - 1) * self.tamanio


def paginacion(pagina: int = Query(1, ge=1, description="Número de página (desde 1)"),
               tamanio: int = Query(20, ge=1, le=PAGINA_MAX, description="Filas por página")) -> Paginacion:
    return Paginacion(pagina, tamanio)


def respuesta(datos, p: Paginacion, total=None) -> dict:
    return {"datos": datos, "pagina": p.pagina, "tamanio": p.tamanio, "total": total}
