import os
from dotenv import load_dotenv
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

load_dotenv()

# Datos para conectarse a la base (se leen del archivo .env)
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "bodegas")
DB_USER = os.getenv("DB_USER", "app_rw")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

# Armamos el texto de conexion
DSN = f"host={DB_HOST} port={DB_PORT} dbname={DB_NAME} user={DB_USER}"
if DB_PASSWORD != "":
    DSN = DSN + f" password={DB_PASSWORD}"

# Pool: un grupo de conexiones abiertas que se reutilizan
pool = ConnectionPool(
    conninfo=DSN,
    min_size=1,
    max_size=10,
    kwargs={"autocommit": True, "row_factory": dict_row},
    open=False,
)


# Cada endpoint pide una conexion prestada y despues la devuelve
def get_db_connection():
    with pool.connection() as conn:
        yield conn
