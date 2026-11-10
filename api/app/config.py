import os

from dotenv import load_dotenv

load_dotenv()

# CORS: URLs autorizadas para consumir la API.
CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()]

# Max de filas
PAGINA_MAX = 100
