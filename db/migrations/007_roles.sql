-- 007_roles.sql: Configuración de roles y privilegios mínimos (propietario, app_rw y app_ro), separando la gestión de accesos de la definición de credenciales mediante entorno.
SET client_encoding = 'UTF8';  

-- Crear los roles solo si no existen 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_rw') THEN
        CREATE ROLE app_rw LOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_ro') THEN
        CREATE ROLE app_ro LOGIN;
    END IF;
END
$$;


-- 1. Quitar privilegios públicos

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
-- Las funciones se pueden ejecutar por PUBLIC por defecto: se revoca y se
-- otorga explícitamente.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL PROCEDURES IN SCHEMA public FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON ROUTINES FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO app_rw, app_ro;


-- 2. app_rw: lo que necesita la API

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_rw;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_rw;
GRANT EXECUTE ON ALL FUNCTIONS  IN SCHEMA public TO app_rw;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO app_rw;

-- La auditoría solo la escribe el trigger (SECURITY DEFINER): la API puede leerla pero no insertar, modificar ni borrar registros de auditoría.
REVOKE INSERT, UPDATE, DELETE ON auditoria_precio FROM app_rw;

-- Objetos que se creen en el futuro con este mismo propietario.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON ROUTINES TO app_rw;


-- 3. app_ro: solo lectura

GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_ro;
GRANT EXECUTE ON FUNCTION fn_stock_sala(INTEGER, INTEGER),
                          fn_total_comprobante(INTEGER),
                          fn_subtotal_bruto_comprobante(INTEGER),
                          fn_descuento_cliente(INTEGER),
                          fn_descuento_por_tipo(VARCHAR),
                          fn_antiguedad_anios(DATE),
                          fn_subtotal_renglon(INTEGER, NUMERIC, NUMERIC)
      TO app_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_ro;

-- La vista materializada la refresca el propietario (no se otorga a la API).
