#!/bin/bash
# =====================================================================
# Inicialización de la base en el contenedor de PostgreSQL.
# La imagen oficial ejecuta este script UNA sola vez, cuando el volumen de
# datos está vacío (para reiniciar: docker compose down -v).
#
# 1. Crea los roles: bodega_owner (propietario del esquema), app_rw (API)
#    y app_ro (consultas), con contraseñas tomadas de variables de entorno.
# 2. Aplica las migraciones 001..008 CONECTADO COMO bodega_owner, para que
#    tablas, funciones y procedimientos SECURITY DEFINER sean suyos y no del
#    superusuario.
# Las contraseñas nunca se escriben en el repositorio: vienen del archivo .env.
# =====================================================================
set -euo pipefail

: "${BODEGA_OWNER_PASSWORD:?Falta BODEGA_OWNER_PASSWORD en .env}"
: "${APP_RW_PASSWORD:?Falta APP_RW_PASSWORD en .env}"
: "${APP_RO_PASSWORD:?Falta APP_RO_PASSWORD en .env}"
DB="${POSTGRES_DB:-bodegas}"
MIGRACIONES="${MIGRACIONES_DIR:-/migraciones}"

echo ">> Creando roles"
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER:-postgres}" --dbname "$DB" \
     -v owner_pw="$BODEGA_OWNER_PASSWORD" -v rw_pw="$APP_RW_PASSWORD" -v ro_pw="$APP_RO_PASSWORD" \
     -v db="$DB" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', r)
  FROM unnest(ARRAY['bodega_owner', 'app_rw', 'app_ro']) AS r
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) \gexec
ALTER ROLE bodega_owner PASSWORD :'owner_pw';
ALTER ROLE app_rw       PASSWORD :'rw_pw';
ALTER ROLE app_ro       PASSWORD :'ro_pw';
-- Ningún rol de la aplicación es superusuario ni puede crear roles o bases.
ALTER ROLE app_rw NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER ROLE app_ro NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER DATABASE :"db" OWNER TO bodega_owner;
ALTER SCHEMA public OWNER TO bodega_owner;
ALTER DATABASE :"db" SET timezone TO 'America/Argentina/Mendoza';
REVOKE ALL ON DATABASE :"db" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"db" TO app_rw, app_ro;
SQL

echo ">> Aplicando migraciones como bodega_owner"
for f in "$MIGRACIONES"/0*.sql; do
  echo "   - $(basename "$f")"
  PGOPTIONS="-c role=bodega_owner" psql -q -v ON_ERROR_STOP=1 \
      --username "${POSTGRES_USER:-postgres}" --dbname "$DB" -f "$f"
done
echo ">> Base lista (sin datos). Para cargar el dataset: docker compose --profile seed run --rm seed"
