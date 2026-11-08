#!/bin/bash
# Compara cuatro formas de insertar 20.000 clientes usando solo psql.
#   PSQL="psql -h localhost -U bodega_owner -d bodegas" bash db/seed/benchmark_psql.sh
# Requiere haber generado los CSV (python db/seed/seed.py generar).
set -e
cd "$(dirname "$0")"
PSQL=${PSQL:-"psql -d bodegas"}
TMP=$(mktemp -d)
python3 - "$TMP" <<'PY'
import csv, sys
tmp = sys.argv[1]
filas = list(csv.reader(open("datos/cliente.csv", encoding="utf-8")))[1:20001]
def lit(v): return "'" + v.replace("'", "''") + "'"
vals = ["(" + ",".join(lit(v) for v in f) + ")" for f in filas]
with open(f"{tmp}/fila_por_fila.sql", "w") as o:
    for v in vals: o.write(f"INSERT INTO bench_cliente VALUES {v};\n")
with open(f"{tmp}/lotes.sql", "w") as o:
    for i in range(0, len(vals), 1000): o.write("INSERT INTO bench_cliente VALUES " + ",".join(vals[i:i+1000]) + ";\n")
with open(f"{tmp}/datos.csv", "w") as o:
    csv.writer(o).writerows(filas)
PY
medir() { local TIMEFORMAT=%R; { time "$@" > /dev/null 2>&1; } 2>&1; }
# Tabla normal (con WAL), igual que las reales
preparar_normal() { $PSQL -q -c "SET client_min_messages=warning" -c "DROP TABLE IF EXISTS bench_cliente" -c "CREATE TABLE bench_cliente (LIKE cliente)"; }
preparar_normal; echo "Fila por fila, autocommit:      $(medir $PSQL -q -f $TMP/fila_por_fila.sql) s"
preparar_normal; echo "Fila por fila, una transaccion: $(medir $PSQL -q -1 -f $TMP/fila_por_fila.sql) s"
preparar_normal; echo "INSERT multi-fila de a 1.000:   $(medir $PSQL -q -1 -f $TMP/lotes.sql) s"
preparar_normal; echo "COPY:                           $(medir $PSQL -q -c "\\copy bench_cliente FROM '$TMP/datos.csv' WITH (FORMAT csv)") s"
$PSQL -q -c "DROP TABLE bench_cliente"
rm -rf "$TMP"
