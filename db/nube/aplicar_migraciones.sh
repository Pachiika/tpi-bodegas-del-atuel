# Script de despliegue en la nube: aplica secuencialmente las migraciones utilizando las credenciales del usuario propietario y asigna los permisos de los roles de la API de forma segura mediante variables de entorno.
set -euo pipefail
: "${OWNER_URL:?Definir OWNER_URL (con sslmode=require)}"
: "${APP_RW_PASSWORD:?Definir APP_RW_PASSWORD}"
: "${APP_RO_PASSWORD:?Definir APP_RO_PASSWORD}"
cd "$(dirname "$0")/../.."

echo ">> Conexión cifrada:"
psql "$OWNER_URL" -Atc "SELECT 'usuario=' || current_user || '  ssl=' || s.ssl || '  postgres=' || current_setting('server_version')
                          FROM pg_stat_ssl s WHERE s.pid = pg_backend_pid()"

echo ">> Roles app_rw y app_ro (requiere que el usuario dueño tenga CREATEROLE)"
psql "$OWNER_URL" -v ON_ERROR_STOP=1 -v rw_pw="$APP_RW_PASSWORD" -v ro_pw="$APP_RO_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', r)
  FROM unnest(ARRAY['app_rw', 'app_ro']) AS r
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) \gexec
ALTER ROLE app_rw PASSWORD :'rw_pw';
ALTER ROLE app_ro PASSWORD :'ro_pw';
SELECT format('GRANT CONNECT ON DATABASE %I TO app_rw, app_ro', current_database()) \gexec
SELECT format('ALTER DATABASE %I SET timezone TO %L', current_database(), 'America/Argentina/Mendoza') \gexec
SQL

echo ">> Migraciones"
for f in db/migrations/0*.sql; do
  echo "   - $(basename "$f")"
  psql "$OWNER_URL" -q -v ON_ERROR_STOP=1 -f "$f"
done

echo ">> Pruebas de reglas (terminan en ROLLBACK)"
psql "$OWNER_URL" -q -f db/tests/db_tests.sql 2>&1 | tail -2
echo "Listo. Cargar datos con:  DATABASE_URL_OWNER=\"\$OWNER_URL\" python db/seed/seed.py todo"
