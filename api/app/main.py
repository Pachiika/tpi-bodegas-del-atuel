# API REST Bodegas del Atuel (FastAPI + psycopg3, sin ORM). Documentación: /docs
import logging
from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from psycopg_pool import PoolTimeout

from . import config, db
from .errores import manejar_error_postgres, manejar_pool_agotado
from .routers import catalogos, clientes, comprobantes, documentos, reportes, vinos

logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def ciclo_de_vida(app: FastAPI):
    db.pool.open()
    yield
    db.pool.close()


app = FastAPI(
    title="Bodegas del Atuel - API",
    version="1.0.0",
    description=("API del TPI de Bases de Datos. Las reglas de negocio viven en PostgreSQL; "
                 "la API traduce sus errores (SQLSTATE) a códigos HTTP."),
    lifespan=ciclo_de_vida,
)
app.add_middleware(CORSMiddleware, allow_origins=config.CORS_ORIGINS,
                   allow_methods=["*"], allow_headers=["*"])
app.add_exception_handler(psycopg.Error, manejar_error_postgres)
app.add_exception_handler(PoolTimeout, manejar_pool_agotado)

for r in (catalogos.router, vinos.router, clientes.router, comprobantes.router,
          documentos.transferencias, documentos.ingresos, reportes.router):
    app.include_router(r)
