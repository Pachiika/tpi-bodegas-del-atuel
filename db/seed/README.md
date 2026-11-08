# Carga masiva (etapa 3)

```
db/seed/
├── catalogos/          CSV de catálogos reales (cepas, maridajes, departamentos, localidades)
├── seed.py             generador + carga con COPY + controles + benchmark
├── cargar_psql.sql     alternativa de carga solo con psql (\copy)
├── control.sql         consultas de control (deben dar 0 problemas)
├── benchmark_psql.sh   fila por fila vs lotes vs COPY, solo con psql
└── datos/              CSV generados (NO se suben a Git: se regeneran)
```

## Con Docker (recomendado)

```bash
docker compose up -d --build                 # base vacía con las migraciones aplicadas
docker compose --profile seed run --rm seed  # genera los CSV, los carga y corre los controles
```

## Sin Docker

Requisitos: Python 3.10+, `pip install "psycopg[binary]"` (el generador no usa otras librerías).
La carga se hace con el rol **propietario** (necesita `ALTER TABLE ... DISABLE TRIGGER`), nunca con `app_rw`.

```bash
export DATABASE_URL_OWNER="host=localhost dbname=bodegas user=bodega_owner password=****"
export SEED_FECHA_REFERENCIA=$(date +%F)    # opcional: "hoy" para el dataset (por defecto 2026-11-01)

python db/seed/seed.py generar     # escribe db/seed/datos/*.csv (≈ 8 s)
python db/seed/seed.py cargar      # COPY de las 26 tablas + setval + REFRESH + ANALYZE + controles (≈ 11 s)
python db/seed/seed.py controles   # solo las consultas de control
python db/seed/seed.py benchmark   # fila por fila vs executemany vs COPY
python db/seed/seed.py todo        # generar + cargar + controles
```

La carga exige que la base esté **vacía** (se aborta si ya hay vinos). Para recargar desde cero en Docker:
`docker compose down -v && docker compose up -d` (borra el volumen de datos).

Alternativa solo con psql (desde la raíz del repo, con los CSV ya generados):

```bash
psql -U bodega_owner -d bodegas -f db/seed/cargar_psql.sql
```

## Reproducibilidad

Misma semilla (`SEMILLA = 2026`) y misma fecha de referencia ⇒ mismos CSV, byte a byte:

```bash
python db/seed/seed.py generar && sha256sum db/seed/datos/*.csv > /tmp/a
python db/seed/seed.py generar && sha256sum db/seed/datos/*.csv | diff - /tmp/a && echo IDENTICOS
```

Informe completo (volúmenes, tiempos, triggers, controles): [`docs/04_carga_masiva.md`](../../docs/04_carga_masiva.md).
