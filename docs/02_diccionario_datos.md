-- =============================================
-- generar_diccionario.sql
-- Genera el diccionario de datos a partir de la base.
-- Asi el diccionario siempre coincide con el esquema fisico.
--
-- Como se usa (desde la carpeta del repo):
-- psql -U postgres -d bodegas -q -At -f docs/generar_diccionario.sql -o docs/02_diccionario_datos.md
-- =============================================
SET client_encoding = 'UTF8';


-- ---------- Titulo ----------
SELECT '# 2. Diccionario de datos';
SELECT '';
SELECT 'Este archivo se genera con docs/generar_diccionario.sql, no se escribe a mano.';
SELECT '';


-- ---------- Tipos ENUM ----------
SELECT '## 2.1 Tipos enumerados';
SELECT '';
SELECT '| Tipo | Valores |';
SELECT '|---|---|';

SELECT '| ' || t.typname || ' | ' || string_agg(e.enumlabel, ', ' ORDER BY e.enumsortorder) || ' |'
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
GROUP BY t.typname
ORDER BY t.typname;

SELECT '';


-- ---------- Dominios ----------
SELECT '## 2.2 Dominios';
SELECT '';
SELECT '| Dominio | Tipo base | CondiciÃ³n |';
SELECT '|---|---|---|';

SELECT '| ' || d.domain_name || ' | ' || d.data_type || ' | ' || c.check_clause || ' |'
FROM information_schema.domains d
JOIN information_schema.domain_constraints dc ON dc.domain_name = d.domain_name
JOIN information_schema.check_constraints c ON c.constraint_name = dc.constraint_name
WHERE d.domain_schema = 'public'
ORDER BY d.domain_name;

SELECT '';


-- ---------- Tablas y columnas ----------
-- Para cada tabla saca el titulo, la descripcion, el encabezado
-- y despues una fila por columna.
-- La columna "orden" sirve para que el titulo salga antes que las columnas.
SELECT '## 2.3 Tablas';
SELECT '';

SELECT linea
FROM (
    -- titulo y descripcion de la tabla
    SELECT table_name::text AS tabla, 0 AS orden,
           '### ' || table_name || E'\n\n'
           || COALESCE(obj_description(table_name::text::regclass), '') || E'\n\n'
           || E'| Columna | Tipo | Nulos | Default | DescripciÃ³n |\n|---|---|---|---|---|' AS linea
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'

    UNION ALL

    -- una fila por columna
    SELECT table_name::text, ordinal_position::int,
           '| ' || column_name
           || ' | ' || CASE WHEN domain_name IS NOT NULL THEN domain_name
                            WHEN character_maximum_length IS NOT NULL
                                 THEN data_type || '(' || character_maximum_length || ')'
                            ELSE data_type END
           || ' | ' || CASE WHEN is_nullable = 'YES' THEN 'sÃ­' ELSE 'no' END
           || ' | ' || COALESCE(column_default, '-')
           || ' | ' || COALESCE(col_description(table_name::text::regclass, ordinal_position::int), '-')
           || ' |'
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name IN (SELECT table_name FROM information_schema.tables
                         WHERE table_schema = 'public' AND table_type = 'BASE TABLE')

    UNION ALL

    -- linea en blanco al final de cada tabla
    SELECT table_name::text, 9999, ''
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
) x
ORDER BY tabla, orden;


-- ---------- Restricciones ----------
-- PK, FK, UNIQUE y CHECK de todas las tablas.
-- Los NOT NULL no se listan porque ya estan en la columna "Nulos".
SELECT '## 2.4 Restricciones';
SELECT '';
SELECT '| Tabla | Nombre | Tipo | DefiniciÃ³n |';
SELECT '|---|---|---|---|';

SELECT '| ' || conrelid::regclass || ' | ' || conname || ' | '
       || CASE contype WHEN 'p' THEN 'PRIMARY KEY'
                       WHEN 'f' THEN 'FOREIGN KEY'
                       WHEN 'u' THEN 'UNIQUE'
                       WHEN 'c' THEN 'CHECK' END
       || ' | ' || pg_get_constraintdef(oid) || ' |'
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND conrelid <> 0                       -- saca las de los dominios
  AND contype IN ('p', 'f', 'u', 'c')     -- saca los NOT NULL
ORDER BY conrelid::regclass::text, contype, conname;

SELECT '';


-- ---------- Triggers ----------
SELECT '## 2.5 Triggers';
SELECT '';
SELECT '| Tabla | Trigger | Momento | Evento |';
SELECT '|---|---|---|---|';

SELECT '| ' || event_object_table || ' | ' || trigger_name || ' | '
       || action_timing || ' | ' || string_agg(event_manipulation, ', ') || ' |'
FROM information_schema.triggers
WHERE trigger_schema = 'public'
GROUP BY event_object_table, trigger_name, action_timing
ORDER BY event_object_table, trigger_name;

SELECT '';


-- ---------- Vistas ----------
SELECT '## 2.6 Vistas';
SELECT '';
SELECT '| Vista | DescripciÃ³n |';
SELECT '|---|---|';

SELECT '| ' || c.relname
       || CASE WHEN c.relkind = 'm' THEN ' (materializada)' ELSE '' END
       || ' | ' || COALESCE(obj_description(c.oid), '-') || ' |'
FROM pg_class c
WHERE c.relnamespace = 'public'::regnamespace
  AND c.relkind IN ('v', 'm')
ORDER BY c.relname;
