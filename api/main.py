from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from database import get_db_connection

app = FastAPI(title="Bodegas del Atuel - API")

# Permitir peticiones desde el frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"status": "ok", "message": "API Bodegas del Atuel funcionando"}

# Endpoint 1: Listar catálogo de vinos
@app.get("/vinos")
def get_vinos():
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT cod_vino, nombre, tipo, anada, precio FROM vino ORDER BY cod_vino;")
            return cur.fetchall()

# Endpoint 2: Consultar stock total por vino usando la vista SQL
@app.get("/stock")
def get_stock():
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM vw_stock_total_vino ORDER BY stock_total DESC;")
            return cur.fetchall()

# Endpoint 3: Consultar salas de venta
@app.get("/salas")
def get_salas():
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT s.id_sala, s.calle, s.numero, l.nombre AS localidad 
                FROM sala_venta s 
                JOIN localidad l ON s.cp_localidad = l.codigo_postal;
            """)
            return cur.fetchall()