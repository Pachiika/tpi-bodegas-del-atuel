"""
Carga masiva reproducible · Bodegas del Atuel
=============================================

Uso (desde la raíz del repositorio):

    python db/seed/seed.py generar      # genera los CSV en db/seed/datos/
    python db/seed/seed.py cargar       # los carga con COPY (psycopg)
    python db/seed/seed.py todo         # generar + cargar + controles
    python db/seed/seed.py benchmark    # compara fila por fila vs lotes vs COPY

La conexión se toma de la variable de entorno DATABASE_URL_OWNER (la carga
la hace el rol PROPIETARIO, no el de la API). Ejemplo:

    export DATABASE_URL_OWNER="postgresql://bodega_owner:****@localhost:5432/bodegas"

Reproducibilidad
----------------
* random.seed(SEMILLA) y Faker.seed(SEMILLA) (clase propia, sin librerías
  externas): dos ejecuciones con la misma versión de Python generan exactamente los mismos CSV
  (se puede verificar con:  sha256sum db/seed/datos/*.csv).
* Los catálogos (cepas, maridajes, departamentos y localidades de Mendoza)
  NO se generan: se leen de db/seed/catalogos/*.csv.

Coherencia de los datos
-----------------------
* Fechas lógicas: un cliente compra después de su fecha de alta; los vinos
  vendidos son de añadas anteriores al año de la venta; la cosecha cae en
  febrero-abril del año de su campaña.
* Porcentajes de corte que suman exactamente 100.
* Descuento del renglón = descuento del tipo de cliente (10/20/30 %),
  subtotales y totales calculados con el mismo redondeo que las funciones
  de la base (fn_subtotal_renglon).
* Stocks finales siempre >= 0.

Triggers durante la carga
-------------------------
La carga del HISTORIAL (ventas, ingresos y transferencias ya procesados,
con fechas pasadas) chocaría con los triggers: la fecha de confección se
forzaría a hoy, los documentos no podrían nacer "procesados" y cada venta
volvería a descontar stock. Por eso se hace:

    ALTER TABLE ... DISABLE TRIGGER USER;   -- solo triggers propios
    COPY ...;
    ALTER TABLE ... ENABLE TRIGGER USER;

DISABLE TRIGGER USER deja ACTIVOS los triggers internos de las claves
foráneas, así que la integridad referencial se sigue verificando. Lo que
dejan de verificar los triggers propios (totales, stock, suma de corte) se
valida después con las consultas de control (db/seed/control.sql).
Riesgo: si el generador tuviera un error, los datos podrían violar una
regla sin que nadie lo note; por eso los controles son obligatorios y la
carga termina con error si alguno encuentra inconsistencias.
"""

from __future__ import annotations

import csv
import os
import random
import sys
import time
from datetime import date, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path

# Generador de nombres propio (antes se usaba Faker). Se dejó una clase mínima
# con listas fijas para que la carga no dependa de librerías externas y para que
# los datos sean idénticos en cualquier máquina (Faker cambia entre versiones).
import random as _r
_N=["Juan","María","Lucía","Pedro","Sofía","Martín","Ana","Diego","Carla","Jorge","Laura","Pablo","Valentina","Tomás","Julieta"]
_A=["Gómez","Pérez","Rodríguez","Fernández","López","Martínez","García","Sánchez","Romero","Sosa","Torres","Álvarez","Ruiz","Díaz","Moreno","Herrera","Medina","Castro","Ortiz","Rojas"]
_C=["San Martín","Belgrano","Mitre","Sarmiento","Rivadavia","Moreno","Las Heras","Pellegrini","Hipólito Yrigoyen","El Libertador","Godoy Cruz","Alem"]
class Faker:
    _rnd=_r.Random(0)
    def __init__(self, locale=None): pass
    @classmethod
    def seed(cls, s): cls._rnd=_r.Random(s)
    def first_name(self): return self._rnd.choice(_N)
    def last_name(self): return self._rnd.choice(_A)
    def name(self): return f"{self.first_name()} {self.last_name()}"
    def street_name(self): return self._rnd.choice(_C)
    def company(self): return f"{self.last_name()} {self._rnd.choice(['S.A.','S.R.L.','Hnos.','e Hijos'])}"

SEMILLA = 2026
# Fecha de referencia de los datos. Por defecto es fija (datos 100 % reproducibles).
# Las consultas de "la última semana", "los últimos 15 días", etc. se calculan con
# CURRENT_DATE: para la demo conviene regenerar con la fecha del día, por ejemplo
#     SEED_FECHA_REFERENCIA=$(date +%F) python db/seed/seed.py generar
# (con la misma semilla y la misma fecha, los datos vuelven a ser idénticos).
HOY = date.fromisoformat(os.environ.get("SEED_FECHA_REFERENCIA") or "2026-11-01")
DIR_SEED = Path(__file__).resolve().parent
DIR_CATALOGOS = DIR_SEED / "catalogos"
DIR_DATOS = DIR_SEED / "datos"

# Volúmenes (ver docs/04_carga_masiva.md)
N_BODEGAS = 12
N_TRANSPORTISTAS = 15
N_SALAS = 40
N_FINCAS = 60
PARCELAS_POR_FINCA = (7, 15)
CAMPANIAS = [HOY.year - i for i in range(5, 0, -1)]   # últimas 5 campañas
N_VINOS = 600
N_CLIENTES = 20_000
N_COMPROBANTES = 150_000
N_INGRESOS = 2_000
N_TRANSFERENCIAS = 3_000

CENT = Decimal("0.01")


def redondear(x: Decimal) -> Decimal:
    """Mismo redondeo que ROUND(numeric, 2) de PostgreSQL (mitad hacia arriba)."""
    return x.quantize(CENT, rounding=ROUND_HALF_UP)


def subtotal_renglon(cantidad: int, precio: Decimal, descuento: Decimal) -> Decimal:
    """Igual que fn_subtotal_renglon en la base."""
    return redondear(Decimal(cantidad) * precio * (1 - descuento / Decimal(100)))


def fecha_al_azar(desde: date, hasta: date) -> date:
    return desde + timedelta(days=random.randint(0, (hasta - desde).days))


def cuit(prefijo: str, usados: set[str]) -> str:
    while True:
        valor = prefijo + "".join(str(random.randint(0, 9)) for _ in range(9))
        if valor not in usados:
            usados.add(valor)
            return valor


def leer_catalogo(nombre: str) -> list[dict]:
    with open(DIR_CATALOGOS / nombre, encoding="utf-8") as f:
        return list(csv.DictReader(f))


class Escritor:
    """Escribe una tabla en CSV (formato que entiende COPY ... CSV HEADER)."""

    def __init__(self):
        DIR_DATOS.mkdir(parents=True, exist_ok=True)
        self.conteos: dict[str, int] = {}

    def escribir(self, tabla: str, columnas: list[str], filas):
        n = 0
        with open(DIR_DATOS / f"{tabla}.csv", "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(columnas)
            for fila in filas:
                w.writerow(["" if v is None else v for v in fila])
                n += 1
        self.conteos[tabla] = n
        print(f"  {tabla:<24} {n:>9,} filas".replace(",", "."))


# =====================================================================
# Generación
# =====================================================================
def generar():
    random.seed(SEMILLA)
    Faker.seed(SEMILLA)
    fake = Faker("es_AR")
    out = Escritor()
    cuits: set[str] = set()
    t0 = time.perf_counter()
    print(f"Generando datos con semilla {SEMILLA} en {DIR_DATOS} ...")

    # ---------------- Catálogos reales ----------------
    cepas = leer_catalogo("cepas.csv")
    for i, c in enumerate(cepas, 1):
        c["id"] = i
    out.escribir("cepa", ["id_cepa", "nombre", "tipo"],
                 ((c["id"], c["nombre"], c["tipo"]) for c in cepas))
    cepa_id = {c["nombre"]: c["id"] for c in cepas}
    tintas = [c["id"] for c in cepas if c["tipo"] == "tinta"]
    blancas = [c["id"] for c in cepas if c["tipo"] == "blanca"]

    maridajes = leer_catalogo("maridajes.csv")
    out.escribir("maridaje", ["id_maridaje", "nombre", "temperatura_servicio"],
                 ((i, m["nombre"], m["temperatura_servicio"]) for i, m in enumerate(maridajes, 1)))
    marid_id = {m["nombre"]: i for i, m in enumerate(maridajes, 1)}

    deptos = leer_catalogo("departamentos.csv")
    out.escribir("departamento", ["id_departamento", "nombre", "provincia"],
                 ((i, d["nombre"], d["provincia"]) for i, d in enumerate(deptos, 1)))

    locs = leer_catalogo("localidades.csv")
    cps = [l["codigo_postal"] for l in locs]
    out.escribir("localidad", ["codigo_postal", "nombre", "provincia", "encargado_regional"],
                 ((l["codigo_postal"], l["nombre"], l["provincia"], fake.name()) for l in locs))

    # ---------------- Bodegas ----------------
    nombres_bodega = ["Atuel Viejo", "Cerro Nevado", "Rama Caída", "Los Reyunos", "El Nihuil",
                      "Valle Grande", "Cañón del Atuel", "La Llave", "Cuadro Nacional",
                      "Las Paredes", "Monte Comán", "Salto de las Rosas"]
    bodegas = []
    for n in nombres_bodega[:N_BODEGAS]:
        bodegas.append((cuit("30", cuits), f"Bodega {n} S.A.",
                        f"{fake.street_name()} {random.randint(100, 9999)}, {random.choice(locs)['nombre']}"))
    out.escribir("bodega", ["cuit", "razon_social", "domicilio"], bodegas)
    cuits_bodega = [b[0] for b in bodegas]

    # ---------------- Transportistas ----------------
    transportistas = []
    for i in range(1, N_TRANSPORTISTAS + 1):
        razon = f"{fake.last_name()} Logística {random.choice(['S.R.L.', 'S.A.', 'y Cía.'])}"
        slug = "".join(ch for ch in razon.lower() if ch.isalnum())[:14]
        transportistas.append((i, razon, cuit("30", cuits), f"contacto{i}@{slug}.com.ar",
                               f"+54 260 4{random.randint(100000, 999999)}",
                               f"{fake.street_name()} {random.randint(10, 3000)}, {random.choice(locs)['nombre']}"))
    out.escribir("transportista", ["codigo_transporte", "razon_social", "cuit", "email", "telefono", "domicilio"],
                 transportistas)
    cobertura = set()
    for t in transportistas:
        for cp in random.sample(cps, random.randint(3, 6)):
            cobertura.add((t[0], cp))
    # General Alvear queda sin cobertura de algunos transportistas (consulta I1).
    out.escribir("transportista_localidad", ["codigo_transporte", "cp_localidad"], sorted(cobertura))

    # ---------------- Salas y empleados ----------------
    dias = ["lunes", "martes", "miercoles", "jueves", "viernes", "sabado", "domingo"]
    salas = []
    for i in range(1, N_SALAS + 1):
        cp = "5600" if i <= 4 else random.choice(cps)   # varias salas en San Rafael
        salas.append((i, fake.street_name(), str(random.randint(10, 4000)),
                      random.choice(dias), cp))
    out.escribir("sala_venta", ["id_sala", "calle", "numero", "dia_cierre", "cp_localidad"], salas)

    empleados = []
    for s in salas:
        for _ in range(random.randint(3, 7)):
            ingreso = fecha_al_azar(date(2012, 1, 1), HOY - timedelta(days=30))
            empleados.append((cuit(random.choice(["20", "27"]), cuits), fake.name(), ingreso,
                              Decimal(random.randrange(650_000, 1_800_000, 500)), s[0]))
    out.escribir("empleado", ["cuit", "nombre", "fecha_ingreso", "salario", "id_sala"], empleados)

    # ---------------- Fincas, parcelas, lotes y análisis ----------------
    deptos_vitivinicolas = [1, 2, 4, 5, 6, 7, 8, 10, 11, 12]   # índices en departamentos.csv
    fincas, parcelas = [], []
    for f_id in range(1, N_FINCAS + 1):
        n_parc = random.randint(*PARCELAS_POR_FINCA)
        sup_parcelas = [Decimal(random.randint(150, 1200)) / 100 for _ in range(n_parc)]
        sup_total = sum(sup_parcelas) + Decimal(random.randint(100, 2000)) / 100
        fincas.append((f_id, f"Finca {fake.last_name()} {random.choice(['Norte', 'Sur', 'Alta', 'del Río', 'Vieja', 'Nueva'])}",
                       sup_total, random.choice(deptos_vitivinicolas)))
        for p in range(1, n_parc + 1):
            parcelas.append((f_id, p, sup_parcelas[p - 1], random.randint(1985, 2019),
                             random.choice(tintas if random.random() < 0.75 else blancas)))
    out.escribir("finca", ["id_finca", "nombre", "superficie_ha", "id_departamento"], fincas)
    out.escribir("parcela", ["id_finca", "nro_parcela", "superficie_ha", "anio_plantacion", "id_cepa"], parcelas)

    lotes, analisis = [], []
    nro_lote = 0
    for (f_id, p, sup, anio_plant, _cepa) in parcelas:
        for camp in CAMPANIAS:
            if camp <= anio_plant + 2 or random.random() < 0.04:
                continue                                 # parcela joven o sin cosecha ese año
            nro_lote += 1
            fecha = fecha_al_azar(date(camp, 2, 1), date(camp, 4, 30))
            kilos = redondear(sup * Decimal(random.randint(6000, 14000)))
            lotes.append((nro_lote, f_id, p, camp, fecha, kilos, random.choice(cuits_bodega)))
            for k in range(random.randint(1, 3)):
                analisis.append((len(analisis) + 1, nro_lote, fecha + timedelta(days=random.randint(0, 3) + 7 * k),
                                 Decimal(random.randint(200, 270)) / 10, Decimal(random.randint(320, 390)) / 100,
                                 Decimal(random.randint(450, 850)) / 100))
    out.escribir("lote_uva", ["nro_lote", "id_finca", "nro_parcela", "campania", "fecha_cosecha",
                              "kilos_cosechados", "cuit_bodega"], lotes)
    out.escribir("analisis_calidad", ["id_analisis", "nro_lote", "fecha", "grado_brix", "ph", "acidez_total"], analisis)

    # ---------------- Vinos, composición y maridajes ----------------
    bases = [  # nombre base, tipo, cepas posibles (principal primero), maridajes sugeridos
        ("Malbec", "tinto", ["Malbec", "Cabernet Sauvignon", "Syrah"], ["Carnes rojas", "Quesos duros", "Pastas con salsa roja"]),
        ("Cabernet Sauvignon", "tinto", ["Cabernet Sauvignon", "Malbec", "Merlot"], ["Carnes rojas", "Quesos duros"]),
        ("Merlot", "tinto", ["Merlot", "Cabernet Sauvignon"], ["Carnes blancas", "Pastas con salsa roja"]),
        ("Syrah", "tinto", ["Syrah", "Malbec"], ["Carnes rojas", "Entradas y fiambres"]),
        ("Bonarda", "tinto", ["Bonarda", "Malbec"], ["Pastas con salsa roja", "Entradas y fiambres"]),
        ("Tempranillo", "tinto", ["Tempranillo", "Malbec"], ["Carnes rojas", "Entradas y fiambres"]),
        ("Pinot Noir", "tinto", ["Pinot Noir"], ["Carnes blancas", "Pescados y mariscos"]),
        ("Blend de Tintas", "tinto", ["Malbec", "Cabernet Sauvignon", "Merlot", "Syrah"], ["Carnes rojas", "Quesos duros"]),
        ("Chardonnay", "blanco", ["Chardonnay", "Semillón"], ["Pescados y mariscos", "Carnes blancas", "Quesos blandos"]),
        ("Sauvignon Blanc", "blanco", ["Sauvignon Blanc", "Semillón"], ["Pescados y mariscos", "Entradas y fiambres"]),
        ("Torrontés", "blanco", ["Torrontés"], ["Entradas y fiambres", "Postres"]),
        ("Chenin Blanc", "blanco", ["Chenin Blanc", "Chardonnay"], ["Quesos blandos", "Pescados y mariscos"]),
        ("Semillón", "blanco", ["Semillón", "Sauvignon Blanc"], ["Pescados y mariscos", "Quesos blandos"]),
        ("Rosado de Malbec", "rosado", ["Malbec", "Syrah"], ["Entradas y fiambres", "Carnes blancas"]),
        ("Espumante Brut Nature", "espumante", ["Chardonnay", "Pinot Noir"], ["Entradas y fiambres", "Postres"]),
        ("Espumante Extra Brut", "espumante", ["Chardonnay", "Pinot Noir"], ["Pescados y mariscos", "Postres"]),
    ]
    lineas = [("Joven", 3500, 6000), ("Clásico", 4500, 8000), ("Roble", 6000, 9500),
              ("Selección", 7500, 11000), ("Reserva", 9000, 16000), ("Familia", 11000, 18000),
              ("Single Vineyard", 15000, 24000), ("Gran Reserva", 16000, 30000), ("Icono", 30000, 60000)]
    factor_vol = {187: Decimal("0.32"), 375: Decimal("0.55"), 750: Decimal("1"),
                  1500: Decimal("2.10"), 3000: Decimal("4.50")}

    vinos, composicion, vino_marid = [], [], []
    claves = set()

    def agregar_vino(nombre, tipo, anada, vol, grad, precio, bodega, corte, marids):
        cod = len(vinos) + 1
        vinos.append((cod, nombre, tipo, anada, vol, grad, precio, bodega))
        claves.add((nombre, anada, vol))
        for c_id, pct in corte:
            composicion.append((cod, c_id, pct))
        for m in marids:
            vino_marid.append((cod, m))
        return cod

    # El vino del enunciado (sección 3.3): Malbec Reserva 2021, 750 ml, $12.500, 14 %.
    agregar_vino("Malbec Reserva", "tinto", 2021, 750, Decimal("14.00"), Decimal("12500.00"), cuits_bodega[0],
                 [(cepa_id["Malbec"], Decimal("85")), (cepa_id["Cabernet Sauvignon"], Decimal("15"))],
                 [marid_id["Carnes rojas"], marid_id["Quesos duros"]])

    # Una bodega boutique con solo 3 vinos (la usa la consulta S12: clientes que
    # compraron TODOS los vinos de una bodega).
    boutique = cuits_bodega[-1]
    vinos_boutique = [
        agregar_vino("Torrontés Single Vineyard", "blanco", HOY.year - 3, 750, Decimal("13.00"), Decimal("15800.00"),
                     boutique, [(cepa_id["Torrontés"], Decimal(100))], [marid_id["Entradas y fiambres"]]),
        agregar_vino("Malbec Single Vineyard", "tinto", HOY.year - 3, 750, Decimal("14.50"), Decimal("21500.00"),
                     boutique, [(cepa_id["Malbec"], Decimal(100))], [marid_id["Carnes rojas"]]),
        agregar_vino("Espumante Brut Nature Familia", "espumante", HOY.year - 3, 750, Decimal("12.00"),
                     Decimal("17900.00"), boutique,
                     [(cepa_id["Chardonnay"], Decimal(70)), (cepa_id["Pinot Noir"], Decimal(30))],
                     [marid_id["Postres"]]),
    ]

    while len(vinos) < N_VINOS:
        base, tipo, cepas_base, marids_base = random.choice(bases)
        linea, pmin, pmax = random.choice(lineas)
        nombre = f"{base} {linea}"
        anada = random.randint(HOY.year - 10, HOY.year - 1)
        vol = random.choices([750, 375, 1500, 187, 3000], weights=[70, 12, 10, 5, 3])[0]
        if (nombre, anada, vol) in claves:
            continue
        precio = redondear(Decimal(random.randint(pmin, pmax)) * factor_vol[vol] / 100) * 100
        grad = (Decimal(random.randint(115, 125)) if tipo == "espumante" else Decimal(random.randint(120, 155))) / 10
        # Corte: la cepa principal domina; el resto se reparte hasta 100.
        n_cepas = min(len(cepas_base), random.choice([1, 1, 2, 2, 3]))
        elegidas = [cepas_base[0]] + random.sample(cepas_base[1:], n_cepas - 1)
        if n_cepas == 1:
            corte = [(cepa_id[elegidas[0]], Decimal(100))]
        else:
            principal = random.randint(60, 90)
            resto = 100 - principal
            otros = []
            for _ in range(n_cepas - 2):
                x = random.randint(1, resto - 1)
                otros.append(x)
                resto -= x
            otros.append(resto)
            corte = [(cepa_id[elegidas[0]], Decimal(principal))] + \
                    [(cepa_id[c], Decimal(p)) for c, p in zip(elegidas[1:], otros)]
        marids = random.sample([marid_id[m] for m in marids_base], random.randint(1, len(marids_base)))
        agregar_vino(nombre, tipo, anada, vol, grad, precio, random.choice(cuits_bodega[:-1]), corte, marids)

    out.escribir("vino", ["cod_vino", "nombre", "tipo", "anada", "volumen_ml", "graduacion", "precio", "cuit_bodega"], vinos)
    out.escribir("composicion_vino", ["cod_vino", "id_cepa", "porcentaje"], composicion)
    out.escribir("vino_maridaje", ["cod_vino", "id_maridaje"], vino_marid)
    precio_vino = {v[0]: v[6] for v in vinos}
    vinos_por_anada: dict[int, list[int]] = {}
    for v in vinos:
        vinos_por_anada.setdefault(v[3], []).append(v[0])

    # ---------------- Clientes y subtipos ----------------
    clientes, distribuidores, exportadores, permisos = [], [], [], []
    alta_cliente, tipo_de = {}, {}
    descuento_tipo = {"socio": Decimal(10), "distribuidor": Decimal(20), "exportador": Decimal(30)}
    docs = set()
    paises = ["Brasil", "Estados Unidos", "Reino Unido", "China", "Canadá", "México", "Países Bajos",
              "Alemania", "Japón", "Chile", "Uruguay", "Paraguay"]
    zonas = ["Sur mendocino", "Valle de Uco", "Gran Mendoza", "Este mendocino", "San Juan", "Neuquén",
             "Córdoba", "Buenos Aires", "Patagonia", "NOA"]
    for i in range(1, N_CLIENTES + 1):
        tipo = random.choices(["socio", "distribuidor", "exportador"], weights=[75, 17, 8])[0]
        if tipo == "socio":
            tipo_doc, nombre = "DNI", f"{fake.last_name()}, {fake.first_name()}"
            while True:
                doc = str(random.randint(10_000_000, 46_000_000))
                if ("DNI", doc) not in docs:
                    break
        else:
            tipo_doc, nombre = "CUIT", fake.company()
            doc = cuit("30", cuits)
        docs.add((tipo_doc, doc))
        alta = fecha_al_azar(HOY - timedelta(days=8 * 365), HOY - timedelta(days=15))
        alta_cliente[i], tipo_de[i] = alta, tipo
        clientes.append((i, nombre, tipo_doc, doc, f"{fake.street_name()} {random.randint(1, 5000)}",
                         random.choice(cps), alta, tipo, descuento_tipo[tipo]))
        if tipo == "distribuidor":
            distribuidores.append((i, "distribuidor", random.choice(zonas), f"HAB-{i:06d}"))
        elif tipo == "exportador":
            exportadores.append((i, "exportador", random.choice(paises)))
            for k in range(random.choices([1, 2, 3, 4, 5], weights=[30, 30, 20, 12, 8])[0]):
                emision = fecha_al_azar(alta, HOY)
                permisos.append((f"PE-{i:06d}-{k + 1}", i, emision,
                                 emision + timedelta(days=random.choice([180, 365, 730]))))
    out.escribir("cliente", ["id_cliente", "nombre_o_razon_social", "tipo_doc", "nro_doc", "direccion",
                             "cp_localidad", "fecha_alta", "tipo_cliente", "descuento"], clientes)
    out.escribir("distribuidor", ["id_cliente", "tipo_cliente", "zona_cobertura", "nro_habilitacion"], distribuidores)
    out.escribir("exportador", ["id_cliente", "tipo_cliente", "pais_destino"], exportadores)
    out.escribir("permiso_exportacion", ["cod_permiso", "id_cliente", "fecha_emision", "fecha_vencimiento"], permisos)

    # ---------------- Comprobantes y renglones ----------------
    # Ventas de los últimos 6 años (algunas superan los 5 años: consulta D1).
    inicio_ventas = HOY - timedelta(days=6 * 365)
    # Vinos que se pueden vender cada año: añada anterior al año de la venta.
    elegibles_por_anio = {
        anio: [c for a, lista in sorted(vinos_por_anada.items()) if a < anio for c in lista]
        for anio in range(inicio_ventas.year, HOY.year + 1)
    }
    comprobantes, renglones = [], []
    # El 3 % de los clientes nunca compró (consultas D4 y D6).
    compradores = [c for c in range(1, N_CLIENTES + 1) if random.random() >= 0.03]
    # Diez clientes compraron los tres vinos de la bodega boutique (consulta S12).
    fieles_boutique = random.sample([c for c in compradores
                                     if alta_cliente[c] < HOY - timedelta(days=365)], 10)
    plan_ventas = [(random.choice(compradores), None) for _ in range(N_COMPROBANTES - len(fieles_boutique))]
    plan_ventas += [(c, vinos_boutique) for c in fieles_boutique]
    for nro, (cli, vinos_fijos) in enumerate(plan_ventas, 1):
        desde = max(alta_cliente[cli], inicio_ventas)
        if vinos_fijos:
            desde = max(alta_cliente[cli], date(HOY.year - 2, 1, 1))
        dia = fecha_al_azar(desde, HOY)
        fecha = datetime(dia.year, dia.month, dia.day, random.randint(9, 20), random.randint(0, 59), random.randint(0, 59))
        sala = random.randint(1, N_SALAS)
        elegibles = elegibles_por_anio[dia.year]
        n_ren = random.choices([1, 2, 3, 4, 5, 6], weights=[10, 18, 25, 22, 14, 11])[0]
        desc = descuento_tipo[tipo_de[cli]]
        bruto = total = Decimal(0)
        anios_atras = HOY.year - dia.year
        for cod in (vinos_fijos or random.sample(elegibles, n_ren)):
            cant = random.choices([1, 2, 3, 6, 12], weights=[45, 25, 12, 12, 6])[0]
            if tipo_de[cli] != "socio":
                cant *= random.choice([1, 2, 4])
            # Precio histórico: el actual con ~8 % menos por cada año hacia atrás.
            precio = redondear(precio_vino[cod] * (Decimal(1) - Decimal("0.08") * anios_atras))
            sub = subtotal_renglon(cant, precio, desc)
            bruto += redondear(Decimal(cant) * precio)
            total += sub
            renglones.append((nro, cod, cant, precio, desc, sub))
        comprobantes.append((nro, fecha, cli, sala, bruto, bruto - total, total))
    # Como en un sistema real, el número de comprobante crece con la fecha:
    # se ordena por fecha y se renumera (esto hace útil un índice BRIN sobre fecha).
    orden = sorted(range(len(comprobantes)), key=lambda k: (comprobantes[k][1], k))
    nuevo_nro = {comprobantes[k][0]: i for i, k in enumerate(orden, 1)}
    comprobantes = [(nuevo_nro[c[0]],) + c[1:] for c in (comprobantes[k] for k in orden)]
    renglones = sorted(((nuevo_nro[r[0]],) + r[1:] for r in renglones), key=lambda r: (r[0], r[1]))
    out.escribir("comprobante", ["nro_comprobante", "fecha", "id_cliente", "id_sala", "subtotal", "descuento", "total"],
                 comprobantes)
    out.escribir("renglon_comprobante", ["nro_comprobante", "cod_vino", "cantidad", "precio_unitario",
                                         "descuento_aplicado", "subtotal"], renglones)

    # ---------------- Ingresos ----------------
    ingresos, ren_ingreso = [], []
    for cod in range(1, N_INGRESOS + 1):
        if random.random() < 0.10:
            fecha = fecha_al_azar(HOY - timedelta(days=90), HOY)
        else:
            fecha = fecha_al_azar(HOY - timedelta(days=3 * 365), HOY)
        dias_atras = (HOY - fecha).days
        if dias_atras > 20:
            estado = "procesado"
        else:
            estado = random.choice(["en_confeccion", "terminado", "procesado"])
        ingresos.append((cod, fecha, estado, random.randint(1, N_TRANSPORTISTAS), random.choice(cuits_bodega)))
        for v in random.sample(range(1, N_VINOS + 1), random.randint(1, 6)):
            ren_ingreso.append((cod, v, random.choice([60, 120, 240, 360, 600, 1200])))
    out.escribir("ingreso", ["codigo_ingreso", "fecha", "estado", "codigo_transporte", "cuit_bodega"], ingresos)
    out.escribir("renglon_ingreso", ["codigo_ingreso", "cod_vino", "cantidad"], ren_ingreso)

    # ---------------- Transferencias ----------------
    transferencias, ren_transf = [], []
    for nro in range(1, N_TRANSFERENCIAS + 1):
        if random.random() < 0.10:                       # actividad reciente (S4, S5)
            fecha = fecha_al_azar(HOY - timedelta(days=30), HOY)
        else:
            fecha = fecha_al_azar(HOY - timedelta(days=3 * 365), HOY)
        dias_atras = (HOY - fecha).days
        if dias_atras > 10:
            estado = "procesado" if random.random() < 0.97 else "terminado"
        else:
            estado = random.choice(["en_confeccion", "terminado", "procesado"])
        transferencias.append((nro, random.randint(1, N_SALAS), fecha, estado))
        pedidos = random.sample(range(2, N_VINOS + 1), random.randint(1, 5))
        if dias_atras <= 30 and random.random() < 0.5:
            pedidos.append(1)                            # Malbec Reserva: el más pedido
        for v in pedidos:
            ren_transf.append((nro, v, random.choice([6, 12, 24, 36, 48, 60])))
    out.escribir("transferencia", ["nro_transferencia", "id_sala", "fecha_confeccion", "estado"], transferencias)
    out.escribir("renglon_transferencia", ["nro_transferencia", "cod_vino", "cantidad"], ren_transf)

    # ---------------- Stock final (siempre >= 0) ----------------
    out.escribir("stock_deposito", ["cod_vino", "cantidad"],
                 ((v, random.choice([0, 0] + [random.randint(50, 6000)] * 8)) for v in range(1, N_VINOS + 1)))
    stock_sala = []
    for s in range(1, N_SALAS + 1):
        for v in sorted(random.sample(range(1, N_VINOS + 1), random.randint(50, 90))):
            stock_sala.append((s, v, random.choice([0] + [random.randint(1, 240)] * 9)))
    out.escribir("stock_sala", ["id_sala", "cod_vino", "cantidad"], stock_sala)

    # ---------------- Auditoría de precios histórica ----------------
    auditoria = []
    for i, cod in enumerate(sorted(random.sample(range(1, N_VINOS + 1), 250)), 1):
        actual = precio_vino[cod]
        anterior = redondear(actual / Decimal("1.13"))
        cuando = datetime.combine(fecha_al_azar(HOY - timedelta(days=700), HOY - timedelta(days=1)),
                                  datetime.min.time()) + timedelta(hours=random.randint(8, 19))
        auditoria.append((i, cod, anterior, actual, cuando.strftime("%Y-%m-%d %H:%M:%S-03"), "bodega_owner"))
    out.escribir("auditoria_precio", ["id_auditoria", "cod_vino", "precio_anterior", "precio_nuevo",
                                      "fecha_hora", "usuario"], auditoria)

    print(f"Generación terminada en {time.perf_counter() - t0:.1f} s")
    return out.conteos


# =====================================================================
# Carga con COPY (psycopg)
# =====================================================================
# Orden de carga según las dependencias de las claves foráneas:
ORDEN_CARGA = [
    "localidad", "departamento", "cepa", "maridaje", "bodega", "transportista",
    "transportista_localidad", "sala_venta", "empleado", "finca", "parcela", "lote_uva",
    "analisis_calidad", "vino", "composicion_vino", "vino_maridaje", "cliente",
    "distribuidor", "exportador", "permiso_exportacion", "comprobante", "renglon_comprobante",
    "ingreso", "renglon_ingreso", "transferencia", "renglon_transferencia",
    "stock_deposito", "stock_sala", "auditoria_precio",
]

# Columnas IDENTITY cuya secuencia hay que ajustar después de cargar ids explícitos.
IDENTITIES = {
    "sala_venta": "id_sala", "cepa": "id_cepa", "departamento": "id_departamento", "finca": "id_finca",
    "lote_uva": "nro_lote", "analisis_calidad": "id_analisis", "vino": "cod_vino", "maridaje": "id_maridaje",
    "cliente": "id_cliente", "comprobante": "nro_comprobante", "transportista": "codigo_transporte",
    "ingreso": "codigo_ingreso", "transferencia": "nro_transferencia", "auditoria_precio": "id_auditoria",
}


def conectar():
    import psycopg

    url = os.environ.get("DATABASE_URL_OWNER")
    if not url:
        sys.exit("Falta la variable de entorno DATABASE_URL_OWNER (conexión con el rol propietario).")
    return psycopg.connect(url)


def cargar():
    if not (DIR_DATOS / "vino.csv").exists():
        sys.exit("No hay CSV generados. Ejecutá primero:  python db/seed/seed.py generar")
    t0 = time.perf_counter()
    with conectar() as conn:
        with conn.cursor() as cur:
            vacias = cur.execute("SELECT NOT EXISTS (SELECT 1 FROM vino)").fetchone()[0]
            if not vacias:
                sys.exit("La base ya tiene datos. La carga masiva se hace sobre una base recién migrada.")
            print("Deshabilitando triggers propios (los de FK siguen activos) ...")
            for tabla in ORDEN_CARGA:
                cur.execute(f"ALTER TABLE {tabla} DISABLE TRIGGER USER")
            tiempos = {}
            for tabla in ORDEN_CARGA:
                t = time.perf_counter()
                with open(DIR_DATOS / f"{tabla}.csv", encoding="utf-8") as f:
                    columnas = f.readline().strip()
                    with cur.copy(f"COPY {tabla} ({columnas}) FROM STDIN WITH (FORMAT csv)") as copy:
                        while bloque := f.read(1 << 20):
                            copy.write(bloque)
                tiempos[tabla] = time.perf_counter() - t
                print(f"  COPY {tabla:<24} {tiempos[tabla]:6.2f} s")
            print("Rehabilitando triggers ...")
            for tabla in ORDEN_CARGA:
                cur.execute(f"ALTER TABLE {tabla} ENABLE TRIGGER USER")
            for tabla, col in IDENTITIES.items():
                cur.execute(f"SELECT setval(pg_get_serial_sequence('{tabla}', '{col}'), "
                            f"(SELECT COALESCE(MAX({col}), 0) + 1 FROM {tabla}), false)")
            cur.execute("REFRESH MATERIALIZED VIEW mv_ventas_por_vino")
        conn.commit()
        conn.autocommit = True
        conn.execute("ANALYZE")
    print(f"Carga completa en {time.perf_counter() - t0:.1f} s")
    controles()


def controles():
    """Ejecuta db/seed/control.sql y falla si alguna verificación encuentra inconsistencias."""
    sql = (DIR_SEED / "control.sql").read_text(encoding="utf-8")
    with conectar() as conn, conn.cursor() as cur:
        cur.execute(sql)
        # El último SELECT del archivo devuelve (verificacion, problemas).
        filas = cur.fetchall()
        print("\nConsultas de control:")
        mal = 0
        for verif, problemas in filas:
            print(f"  {'OK ' if problemas == 0 else 'MAL'} {verif:<60} {problemas}")
            mal += problemas
        if mal:
            sys.exit(f"Se encontraron {mal} inconsistencias.")


# =====================================================================
# Benchmark: fila por fila vs executemany vs COPY
# =====================================================================
def benchmark(n: int = 20_000):
    """Inserta n clientes en una tabla temporal con tres métodos y mide el tiempo."""
    random.seed(SEMILLA)
    filas = [(i, f"Cliente {i}", "DNI", str(30_000_000 + i), f"Calle {i}", "5600", HOY, "socio", Decimal(10))
             for i in range(1, n + 1)]
    cols = "id_cliente, nombre_o_razon_social, tipo_doc, nro_doc, direccion, cp_localidad, fecha_alta, tipo_cliente, descuento"
    sql_ins = f"INSERT INTO bench_cliente ({cols}) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)"
    resultados = {}
    with conectar() as conn, conn.cursor() as cur:
        def preparar():
            cur.execute("DROP TABLE IF EXISTS bench_cliente")
            cur.execute("CREATE TEMP TABLE bench_cliente (LIKE cliente INCLUDING DEFAULTS)")

        preparar()
        t = time.perf_counter()
        for fila in filas:                       # una sentencia y un viaje por fila
            cur.execute(sql_ins, fila)
        conn.commit()
        resultados["Fila por fila (execute en un bucle)"] = time.perf_counter() - t

        preparar()
        t = time.perf_counter()
        cur.executemany(sql_ins, filas)          # psycopg 3 usa pipeline: lotes
        conn.commit()
        resultados["Por lotes (executemany)"] = time.perf_counter() - t

        preparar()
        t = time.perf_counter()
        with cur.copy(f"COPY bench_cliente ({cols}) FROM STDIN") as copy:
            for fila in filas:
                copy.write_row(fila)
        conn.commit()
        resultados["COPY"] = time.perf_counter() - t

    print(f"\nInserción de {n:,} filas:".replace(",", "."))
    base = resultados["Fila por fila (execute en un bucle)"]
    for metodo, seg in resultados.items():
        print(f"  {metodo:<38} {seg:7.2f} s   ({base / seg:5.1f}x)")


if __name__ == "__main__":
    accion = sys.argv[1] if len(sys.argv) > 1 else "todo"
    if accion == "generar":
        generar()
    elif accion == "cargar":
        cargar()
    elif accion == "controles":
        controles()
    elif accion == "benchmark":
        benchmark(int(sys.argv[2]) if len(sys.argv) > 2 else 20_000)
    elif accion == "todo":
        generar()
        cargar()
    else:
        sys.exit(__doc__)
