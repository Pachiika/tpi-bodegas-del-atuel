import os

from dotenv import load_dotenv

load_dotenv()

# Desde donde se permite llamar a la API (CORS). En la nube: la URL del front.
CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()]

# Maximo de filas por pagina en los listados.
PAGINA_MAX = 100
