-- =============================================================
-- generar_diccionario.sql
-- Arma docs/02_diccionario_datos.md leyendo el catalogo de PostgreSQL.
-- Como sale de la base, el diccionario siempre coincide con el esquema fisico.
--
-- Uso (desde la raiz del repo):
--   psql -U postgres -d bodegas -q -At -f docs/generar_diccionario.sql -o docs/02_diccionario_datos.md
--   -q  sin mensajes   -At  sin encabezados ni bordes   -o  guarda en archivo
-- =============================================================
SET client_encoding = 'UTF8';


-- ---------- 1) Encabezado ----------
SELECT '# 2. Diccionario de datos' || E'\n\n'
    || 'Generado desde el catálogo de PostgreSQL con `docs/generar_diccionario.sql`. '
    || 'No se edita a mano: si cambia el esquema, se vuelve a generar.' || E'\n\n'
    || '## 2.1 Tipos enumerados' || E'\n\n'
    || '| Tipo | Valores |' || E'\n' || '|---|---|';


-- ---------- 2) Tipos ENUM ----------
SELECT '| `' || t.typname || '` | '
    || string_agg(e.enumlabel, ', ' ORDER BY e.enumsortorder) || ' |'
  FROM pg_type t
  JOIN pg_enum e      ON e.enumtypid = t.oid
  JOIN pg_namespace n ON n.oid = t.typnamespace
 WHERE n.nspname = 'public'
 GROUP BY t.typname
 ORDER BY t.typname;


-- ---------- 3) Dominios ----------
SELECT E'\n## 2.2 Dominios\n\n| Dominio | Tipo base | Restricción |\n|---|---|---|';

SELECT '| `' || t.typname || '` | `' || format_type(t.typbasetype, t.typtypmod) || '` | `'
    || COALESCE((SELECT string_agg(pg_get_constraintdef(co.oid), ' y ')
                   FROM pg_constraint co
                  WHERE co.contypid = t.oid), '—') || '` |'
  FROM pg_type t
  JOIN pg_namespace n ON n.oid = t.typnamespace
 WHERE n.nspname = 'public'
   AND t.typtype = 'd'          -- d = dominio
 ORDER BY t.typname;


-- ---------- 4) Un bloque completo por tabla ----------
SELECT E'\n## Tabla `' || c.relname || E'`\n\n'
    || COALESCE(obj_description(c.oid, 'pg_class'), '(sin descripción)') || E'\n\n'

    -- columnas en el orden en que se crearon
    || E'| Columna | Tipo | Nulos | Default | Descripción |\n|---|---|---|---|---|\n'
    || (SELECT string_agg(
                 '| `' || a.attname || '` | `' || format_type(a.atttypid, a.atttypmod) || '` | '
              || CASE WHEN a.attnotnull THEN 'no' ELSE 'sí' END || ' | '
              || CASE
                   WHEN d.adbin IS NULL THEN '—'
                   WHEN pg_get_expr(d.adbin, d.adrelid) LIKE 'nextval%' THEN 'autoincremental'
                   ELSE '`' || pg_get_expr(d.adbin, d.adrelid) || '`'
                 END || ' | '
              || COALESCE(col_description(c.oid, a.attnum), '—') || ' |',
                 E'\n' ORDER BY a.attnum)
          FROM pg_attribute a
          LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
         WHERE a.attrelid = c.oid
           AND a.attnum > 0           -- saca columnas internas del sistema
           AND NOT a.attisdropped)

    -- restricciones: PK, FK (con ON DELETE / ON UPDATE), UNIQUE y CHECK
    || E'\n\n**Restricciones**\n\n'
    || COALESCE((SELECT string_agg('- `' || co.conname || '`: `' || pg_get_constraintdef(co.oid) || '`',
                                   E'\n' ORDER BY CASE co.contype WHEN 'p' THEN 1 WHEN 'f' THEN 2
                                                                  WHEN 'u' THEN 3 ELSE 4 END,
                                                  co.conname)
                   FROM pg_constraint co
                  WHERE co.conrelid = c.oid), '- (ninguna)')

    -- triggers de la tabla (reglas de negocio que no entran en un CHECK)
    || COALESCE(E'\n\n**Triggers**\n\n'
                || (SELECT string_agg('- `' || tg.tgname || '` → `' || p.proname || '()`',
                                      E'\n' ORDER BY tg.tgname)
                      FROM pg_trigger tg
                      JOIN pg_proc p ON p.oid = tg.tgfoid
                     WHERE tg.tgrelid = c.oid
                       AND NOT tg.tgisinternal), '')   -- los internos son los de las FK
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public'
   AND c.relkind = 'r'           -- r = tabla comun
 ORDER BY c.relname;


-- ---------- 5) Vistas ----------
SELECT E'\n## Vistas\n\n| Vista | Tipo | Descripción |\n|---|---|---|';

SELECT '| `' || c.relname || '` | '
    || CASE c.relkind WHEN 'm' THEN 'materializada' ELSE 'común' END || ' | '
    || COALESCE(obj_description(c.oid, 'pg_class'), '(sin descripción)') || ' |'
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public'
   AND c.relkind IN ('v', 'm')
 ORDER BY c.relname;
