# 9. Backup y restauración

## 9.1 Prueba realizada en local

Formato **custom** (`-Fc`): comprimido, y permite restaurar en paralelo y de forma selectiva con `pg_restore`.

```bash
# 1. Backup
pg_dump -h localhost -U postgres -d bodegas -Fc -f bodegas_$(date +%F).dump
#    -> 9,0 MB, 1,3 s

# 2. Restaurar en una base NUEVA
createdb -h localhost -U postgres -O bodega_owner bodegas_restore
pg_restore -h localhost -U postgres -d bodegas_restore --no-owner --role=bodega_owner -j 4 bodegas_$(date +%F).dump
#    -> 2,0 s, sin errores

# 3. Comparar conteos
psql -d bodegas         -At -f docs/backup/conteos.sql > origen.txt
psql -d bodegas_restore -At -f docs/backup/conteos.sql > restaurada.txt
diff origen.txt restaurada.txt && echo COINCIDEN
```

Resultado:

| Tabla | Origen | Restaurada |
|---|---:|---:|
| cliente | 20.000 | 20.000 |
| comprobante | 150.000 | 150.000 |
| renglon_comprobante | 517.840 | 517.840 |
| vino | 600 | 600 |
| stock_sala | 2.854 | 2.854 |
| transferencia | 3.000 | 3.000 |
| ingreso | 2.000 | 2.000 |
| auditoria_precio | 250 | 250 |
| suma de `comprobante.total` | 23.574.853.380 | 23.574.853.380 |

`COINCIDEN`. Además se corrió `db/tests/db_tests.sql` sobre la base restaurada: **69/69 OK**. Eso confirma que
también volvieron triggers, funciones, procedimientos y permisos, no solo los datos.

Con Docker:

```bash
docker compose exec db pg_dump -U postgres -d bodegas -Fc > bodegas.dump
docker compose exec db createdb -U postgres -O bodega_owner bodegas_restore
docker compose exec -T db pg_restore -U postgres -d bodegas_restore --no-owner --role=bodega_owner < bodegas.dump
```

## 9.2 En la nube

Render Free **no hace backups**, así que se hacen con `pg_dump` desde la PC (con la IP habilitada por un rato):

```bash
pg_dump "$OWNER_URL" -Fc -f bodegas_nube_$(date +%F).dump
createdb bodegas_restore_nube                       # en local (o una base nueva en el proveedor)
pg_restore -d bodegas_restore_nube --no-owner bodegas_nube_$(date +%F).dump
psql -d bodegas_restore_nube -At -f docs/backup/conteos.sql    # comparar con los de la nube
```

Usar la misma versión mayor de `pg_dump` que la del servidor, o una más nueva.
`--no-owner` evita errores cuando el usuario dueño de la nube no existe en la base destino.

## 9.3 Política sugerida

- **Antes de cada cambio de esquema** (nueva migración) y antes de la defensa: `pg_dump -Fc`.
- Guardar los backups **fuera del repositorio** (`backups/` y `*.dump` están en `.gitignore`), porque contienen datos.
- Un backup que nunca se restauró no está probado: repetir la restauración de vez en cuando.
