"""Modelos de entrada (pydantic). Solo validan forma y tipos de datos:
las reglas de negocio (precio > 0, porcentajes que suman 100, stock, etc.)
las hace cumplir la base, y la API traduce el error que devuelve."""
from decimal import Decimal
from typing import Any, Optional

from pydantic import BaseModel, Field


class ComponenteCepa(BaseModel):
    id_cepa: int
    porcentaje: Decimal


class VinoEntrada(BaseModel):
    nombre: str
    tipo: str = Field(description="tinto | blanco | rosado | espumante")
    anada: int
    volumen_ml: int
    graduacion: Decimal
    precio: Decimal
    cuit_bodega: str
    composicion: list[ComponenteCepa] = Field(description="Debe sumar 100 % (RN-05)")
    maridajes: list[int] = []

    model_config = {"json_schema_extra": {"example": {
        "nombre": "Malbec Reserva", "tipo": "tinto", "anada": 2022, "volumen_ml": 750,
        "graduacion": 14.0, "precio": 13500, "cuit_bodega": "30712345671",
        "composicion": [{"id_cepa": 1, "porcentaje": 85}, {"id_cepa": 2, "porcentaje": 15}],
        "maridajes": [1, 3]}}}


class VinoModificacion(BaseModel):
    nombre: str
    tipo: str
    anada: int
    volumen_ml: int
    graduacion: Decimal
    precio: Decimal
    cuit_bodega: str
    composicion: Optional[list[ComponenteCepa]] = Field(
        None, description="Si se envía, reemplaza la composición completa")
    maridajes: Optional[list[int]] = None


class ClienteEntrada(BaseModel):
    nombre_o_razon_social: str
    tipo_doc: str = Field(description="DNI | CUIT | PASAPORTE")
    nro_doc: str
    direccion: str
    cp_localidad: str
    tipo_cliente: str = Field(description="socio | distribuidor | exportador")
    # distribuidor
    zona_cobertura: Optional[str] = None
    nro_habilitacion: Optional[str] = None
    # exportador
    pais_destino_principal: Optional[str] = None


class ClienteModificacion(BaseModel):
    nombre_o_razon_social: str
    tipo_doc: str
    nro_doc: str
    direccion: str
    cp_localidad: str
    zona_cobertura: Optional[str] = None
    nro_habilitacion: Optional[str] = None
    pais_destino_principal: Optional[str] = None


class RenglonVenta(BaseModel):
    cod_vino: int
    cantidad: int


class ComprobanteEntrada(BaseModel):
    id_cliente: int
    id_sala: int
    renglones: list[RenglonVenta] = Field(min_length=1)

    model_config = {"json_schema_extra": {"example": {
        "id_cliente": 1, "id_sala": 1, "renglones": [{"cod_vino": 1, "cantidad": 2}]}}}


class TransferenciaEntrada(BaseModel):
    id_sala: int


class IngresoEntrada(BaseModel):
    codigo_transporte: int
    cuit_bodega: str


class RenglonDocumento(BaseModel):
    cod_vino: int
    cantidad: int


class Pagina(BaseModel):
    datos: list[dict[str, Any]]
    pagina: int
    tamanio: int
    total: Optional[int] = None
