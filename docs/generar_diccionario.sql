-- generar_diccionario.sql
-- Arma docs/02_diccionario_datos.md leyendo el catalogo de PostgreSQL.
-- Uso: psql -U postgres -d bodegas -q -At -f docs/generar_diccionario.sql -o docs/02_diccionario_datos.md
SET client_encoding = 'UTF8';

SELECT '# 2. Diccionario de datos';
SELECT '';

-- 2.1 Tipos enumerados
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

-- 2.2 Dominios (typtype = 'd')
SELECT '## 2.2 Dominios';
SELECT '';
SELECT '| Dominio | Tipo base | Restricción |';
SELECT '|---|---|---|';
SELECT '| ' || t.typname || ' | ' || format_type(t.typbasetype, t.typtypmod)
       || ' | ' || pg_get_constraintdef(co.oid) || ' |'
FROM pg_type t
JOIN pg_constraint co ON co.contypid = t.oid
WHERE t.typtype = 'd'
ORDER BY t.typname;
SELECT '';

-- 2.3 Tablas y columnas (una fila por columna)
SELECT '## 2.3 Tablas y columnas';
SELECT '';
SELECT '| Tabla | Columna | Tipo | Admite nulos | Default | Descripción |';
SELECT '|---|---|---|---|---|---|';
SELECT '| `' || c.relname || '` | ' || a.attname
       || ' | ' || format_type(a.atttypid, a.atttypmod)
       || ' | ' || CASE WHEN a.attnotnull THEN 'No' ELSE 'Sí' END
       || ' | ' || CASE WHEN a.attidentity <> '' THEN 'identidad'
                        ELSE COALESCE(pg_get_expr(d.adbin, d.adrelid), '-') END
       || ' | ' || COALESCE(col_description(c.oid, a.attnum), '-') || ' |'
FROM pg_class c
JOIN pg_attribute a ON a.attrelid = c.oid
LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
WHERE c.relnamespace = 'public'::regnamespace
  AND c.relkind = 'r'          -- r = tabla
  AND a.attnum > 0             -- sin columnas del sistema
  AND NOT a.attisdropped
ORDER BY c.relname, a.attnum;
SELECT '';

-- 2.4 Restricciones (PK, FK, UNIQUE, CHECK)
-- No se listan los NOT NULL porque PostgreSQL 18 los guarda como constraints
-- y ya estan en la columna "Admite nulos".
SELECT '## 2.4 Restricciones';
SELECT '';
SELECT '| Tabla | Nombre | Tipo | Definición |';
SELECT '|---|---|---|---|';
SELECT '| ' || conrelid::regclass::text || ' | ' || conname
       || ' | ' || CASE contype WHEN 'p' THEN 'PRIMARY KEY'
                               WHEN 'f' THEN 'FOREIGN KEY'
                               WHEN 'u' THEN 'UNIQUE'
                               WHEN 'c' THEN 'CHECK' END
       || ' | ' || pg_get_constraintdef(oid) || ' |'
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND conrelid <> 0                      -- saca las de los dominios
  AND contype IN ('p', 'f', 'u', 'c')    -- saca los NOT NULL
ORDER BY conrelid::regclass::text, contype, conname;
SELECT '';

-- 2.5 Triggers (un trigger puede saltar en INSERT y en UPDATE, por eso string_agg)
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

-- 2.6 Vistas (v = vista, m = materializada)
SELECT '## 2.6 Vistas';
SELECT '';
SELECT '| Vista | Descripción |';
SELECT '|---|---|';
SELECT '| ' || c.relname
       || CASE WHEN c.relkind = 'm' THEN ' (materializada)' ELSE '' END
       || ' | ' || COALESCE(obj_description(c.oid), '-') || ' |'
FROM pg_class c
WHERE c.relnamespace = 'public'::regnamespace
  AND c.relkind IN ('v', 'm')
ORDER BY c.relname;