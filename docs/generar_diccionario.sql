-- v4 generador del diccionario (lee el catalogo de PostgreSQL)
SET client_encoding = 'UTF8';

SELECT '# 2. Diccionario de datos';
SELECT '';

SELECT '## 2.1 Tipos enumerados';
SELECT '';
SELECT '| Tipo | Valores |';
SELECT '|---|---|';
SELECT '| ' || t.typname || ' | ' || string_agg(e.enumlabel, ', ' ORDER BY e.enumsortorder) || ' |'
FROM pg_type t JOIN pg_enum e ON e.enumtypid = t.oid
WHERE t.typnamespace = 'public'::regnamespace
GROUP BY t.typname ORDER BY t.typname;
SELECT '';

SELECT '## 2.2 Dominios';
SELECT '';
SELECT '| Dominio | Tipo base | Restricción |';
SELECT '|---|---|---|';
SELECT '| ' || t.typname || ' | ' || format_type(t.typbasetype, t.typtypmod) || ' | ' ||
       COALESCE((SELECT string_agg(replace(pg_get_constraintdef(c.oid), '|', '\|'), '; ')
                 FROM pg_constraint c WHERE c.contypid = t.oid), '-') || ' |'
FROM pg_type t
WHERE t.typtype = 'd' AND t.typnamespace = 'public'::regnamespace
ORDER BY t.typname;
SELECT '';

SELECT '## 2.3 Tablas y columnas';
SELECT '';
SELECT '| Tabla | Columna | Tipo | Admite nulos | Restricciones | Default | Descripción |';
SELECT '|---|---|---|---|---|---|---|';
SELECT '| `' || c.relname || '` | ' || a.attname ||
       ' | ' || format_type(a.atttypid, a.atttypmod) ||
       ' | ' || CASE WHEN a.attnotnull THEN 'No' ELSE 'Sí' END ||
       ' | ' || COALESCE((SELECT string_agg(
                    CASE k.contype WHEN 'p' THEN 'PK'
                                   WHEN 'f' THEN 'FK → ' || k.confrelid::regclass::text
                                   WHEN 'u' THEN 'UNIQUE'
                                   WHEN 'c' THEN 'CHECK' END,
                    ', ' ORDER BY k.contype)
                  FROM pg_constraint k
                  WHERE k.conrelid = c.oid AND a.attnum = ANY (k.conkey)
                    AND k.contype IN ('p','f','u','c')), '-') ||
       ' | ' || COALESCE(replace(pg_get_expr(d.adbin, d.adrelid), '|', '\|'), '-') ||
       ' | ' || COALESCE(col_description(c.oid, a.attnum), '-') || ' |'
FROM pg_class c
JOIN pg_attribute a ON a.attrelid = c.oid
LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'r'
  AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY c.relname, a.attnum;
SELECT '';

SELECT '## 2.4 Restricciones';
SELECT '';
SELECT '| Tabla | Nombre | Tipo | Definición |';
SELECT '|---|---|---|---|';
SELECT '| ' || conrelid::regclass::text || ' | `' || conname || '` | ' ||
       CASE contype WHEN 'p' THEN 'PK' WHEN 'f' THEN 'FK'
                    WHEN 'u' THEN 'UNIQUE' WHEN 'c' THEN 'CHECK' END ||
       ' | `' || replace(pg_get_constraintdef(oid), '|', '\|') || '` |'
FROM pg_constraint
WHERE contype IN ('p','f','u','c') AND conrelid <> 0
  AND connamespace = 'public'::regnamespace
ORDER BY conrelid::regclass::text, contype, conname;
SELECT '';

SELECT '## 2.5 Triggers';
SELECT '';
SELECT '| Tabla | Trigger | Definición |';
SELECT '|---|---|---|';
SELECT '| ' || tgrelid::regclass::text || ' | `' || tgname || '` | `' ||
       replace(pg_get_triggerdef(oid), '|', '\|') || '` |'
FROM pg_trigger
WHERE NOT tgisinternal AND tgrelid::regclass::text IN
      (SELECT relname FROM pg_class WHERE relnamespace = 'public'::regnamespace)
ORDER BY tgrelid::regclass::text, tgname;
SELECT '';

SELECT '## 2.6 Vistas';
SELECT '';
SELECT '| Vista | Tipo | Descripción |';
SELECT '|---|---|---|';
SELECT '| ' || c.relname || ' | ' ||
       CASE WHEN c.relkind = 'm' THEN 'materializada' ELSE 'común' END ||
       ' | ' || COALESCE(obj_description(c.oid, 'pg_class'), '-') || ' |'
FROM pg_class c
WHERE c.relkind IN ('v','m') AND c.relnamespace = 'public'::regnamespace
ORDER BY c.relname;