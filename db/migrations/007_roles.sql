-- =====================================================================
-- 007_roles.sql - Configuración de Roles y Privilegios Mínimos
-- =====================================================================

-- Crear rol de lectura y escritura para la API (nunca usar el superusuario propietario)
CREATE ROLE app_rw LOGIN PASSWORD 'cambiar_por_un_secreto_seguro';

-- Crear rol de solo lectura para reportes o auditoría externa
CREATE ROLE app_ro LOGIN PASSWORD 'cambiar_por_otro_secreto';

-- Revocar privilegios públicos por defecto en el esquema public
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- Otorgar permisos al esquema
GRANT USAGE ON SCHEMA public TO app_rw;
GRANT USAGE ON SCHEMA public TO app_ro;

-- Privilegios operativos para la API (app_rw)[cite: 30]
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO app_rw;

GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public TO app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON ROUTINES TO app_rw;

-- Privilegios de solo lectura para reportes (app_ro)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_ro;