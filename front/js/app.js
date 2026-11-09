// Front de Bodegas del Atuel. Sin frameworks: HTML + JS que llama a la API.
// Regla: el front no calcula importes, descuentos ni stock; los muestra.

const $ = (sel, raiz = document) => raiz.querySelector(sel);
const $$ = (sel, raiz = document) => [...raiz.querySelectorAll(sel)];
const esc = (v) => String(v ?? "").replace(/[&<>"']/g, (c) =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const pesos = (n) => Number(n).toLocaleString("es-AR", { style: "currency", currency: "ARS" });

// ---------------------------------------------------------------- mensajes
function mostrar(texto, tipo = "ok") {
  const m = $("#mensaje");
  m.textContent = texto;
  m.className = tipo;
  clearTimeout(mostrar.t);
  mostrar.t = setTimeout(() => m.classList.add("oculto"), tipo === "error" ? 12000 : 4000);
}
// Envuelve una acción: si la API devuelve error, se muestra su mensaje tal cual.
const intentar = (fn) => async (...args) => {
  try { await fn(...args); } catch (e) { mostrar(e.message, "error"); console.error(e); }
};

// ---------------------------------------------------------------- navegación
function irA(pantalla) {
  $$(".pantalla").forEach((s) => s.classList.toggle("oculto", s.id !== pantalla));
  $$("nav button").forEach((b) => b.classList.toggle("activa", b.dataset.pantalla === pantalla));
  if (pantalla === "tablero") cargarTablero();
  if (pantalla === "transferencias") cargarTransferencias();
}
$$("nav button").forEach((b) => b.addEventListener("click", () => irA(b.dataset.pantalla)));

// ---------------------------------------------------------------- combos comunes
const cache = {};
async function cargarCombos() {
  [cache.cepas, cache.bodegas, cache.salas, cache.maridajes] = await Promise.all([
    API.get("/cepas"), API.get("/bodegas"), API.get("/salas"), API.get("/maridajes")]);
  $$(".combo-cepas").forEach((s) => s.insertAdjacentHTML("beforeend",
    cache.cepas.map((c) => `<option value="${c.id_cepa}">${esc(c.nombre)}</option>`).join("")));
  $$(".combo-bodegas").forEach((s) => s.insertAdjacentHTML("beforeend",
    cache.bodegas.map((b) => `<option value="${esc(b.cuit)}">${esc(b.razon_social)}</option>`).join("")));
  $$(".combo-salas").forEach((s) => s.innerHTML =
    cache.salas.map((x) => `<option value="${x.id_sala}">${x.id_sala} · ${esc(x.nombre)}</option>`).join(""));
  $("#lista-maridajes").innerHTML = cache.maridajes.map((m) =>
    `<label><input type="checkbox" value="${m.id_maridaje}"> ${esc(m.nombre)}</label>`).join("");
}

// =================================================================== 1. CATÁLOGO
const catalogo = { pagina: 1, tamanio: 15, total: 0 };

async function cargarCatalogo() {
  const f = Object.fromEntries(new FormData($("#filtros")));
  const r = await API.get("/vinos", { ...f, pagina: catalogo.pagina, tamanio: catalogo.tamanio });
  catalogo.total = r.total;
  $("#tabla-vinos tbody").innerHTML = r.datos.map((v) => `
    <tr>
      <td>${v.cod_vino}</td><td>${esc(v.nombre)}</td><td>${v.tipo}</td><td>${v.anada}</td>
      <td>${v.volumen_ml}</td><td class="num">${pesos(v.precio)}</td><td>${esc(v.bodega)}</td>
      <td><button data-ver="${v.cod_vino}">Ver</button> <button data-editar="${v.cod_vino}">Editar</button></td>
    </tr>`).join("") || `<tr><td colspan="8">Sin resultados</td></tr>`;
  const paginas = Math.max(1, Math.ceil(r.total / catalogo.tamanio));
  $("#pag-info").textContent = `Página ${catalogo.pagina} de ${paginas} · ${r.total} vinos`;
  $("#pag-ant").disabled = catalogo.pagina <= 1;
  $("#pag-sig").disabled = catalogo.pagina >= paginas;
}

async function verFicha(cod) {
  const v = await API.get(`/vinos/${cod}`);
  const ficha = $("#ficha");
  ficha.innerHTML = `
    <h3>${esc(v.nombre)} ${v.anada} · ${v.volumen_ml} ml</h3>
    <p>${esc(v.bodega)} · ${v.tipo} · ${v.graduacion} % · <strong>${pesos(v.precio)}</strong></p>
    <p><b>Composición:</b> ${v.composicion.map((c) => `${esc(c.nombre)} ${c.porcentaje} %`).join(", ") || "—"}</p>
    <p><b>Maridajes:</b> ${v.maridajes.map((m) => `${esc(m.nombre)} (${m.temperatura_servicio} °C)`).join(", ") || "—"}</p>
    <p><b>Stock:</b> depósito ${v.stock_deposito} · salas ${v.stock_en_salas} · total ${v.stock_total}</p>`;
  ficha.classList.remove("oculto");
  ficha.scrollIntoView({ behavior: "smooth" });
}

$("#filtros").addEventListener("submit", intentar(async (e) => {
  e.preventDefault(); catalogo.pagina = 1; await cargarCatalogo();
}));
$("#pag-ant").addEventListener("click", intentar(async () => { catalogo.pagina--; await cargarCatalogo(); }));
$("#pag-sig").addEventListener("click", intentar(async () => { catalogo.pagina++; await cargarCatalogo(); }));
$("#tabla-vinos").addEventListener("click", intentar(async (e) => {
  if (e.target.dataset.ver) await verFicha(e.target.dataset.ver);
  if (e.target.dataset.editar) { await editarVino(e.target.dataset.editar); irA("vino"); }
}));

// ======================================================= 2. ALTA Y EDICIÓN DE VINO
function filaCepa(id_cepa = "", porcentaje = "") {
  const opciones = cache.cepas.map((c) =>
    `<option value="${c.id_cepa}" ${c.id_cepa == id_cepa ? "selected" : ""}>${esc(c.nombre)}</option>`).join("");
  $("#tabla-composicion tbody").insertAdjacentHTML("beforeend", `
    <tr><td><select class="cepa">${opciones}</select></td>
        <td><input class="porcentaje" type="number" step="0.01" value="${porcentaje}" style="width:6em"></td>
        <td><button type="button" class="quitar">✕</button></td></tr>`);
}

function limpiarVino() {
  const f = $("#form-vino");
  f.reset(); f.cod_vino.value = "";
  $("#tabla-composicion tbody").innerHTML = "";
  filaCepa();
  $("#titulo-vino").textContent = "Alta de vino";
  $("#borrar-vino").classList.add("oculto");
}

async function editarVino(cod) {
  const v = await API.get(`/vinos/${cod}`);
  const f = $("#form-vino");
  ["cod_vino", "nombre", "tipo", "anada", "volumen_ml", "graduacion", "precio", "cuit_bodega"]
    .forEach((k) => { f[k].value = v[k]; });
  $("#tabla-composicion tbody").innerHTML = "";
  v.composicion.forEach((c) => filaCepa(c.id_cepa, c.porcentaje));
  const elegidos = new Set(v.maridajes.map((m) => String(m.id_maridaje)));
  $$("#lista-maridajes input").forEach((i) => { i.checked = elegidos.has(i.value); });
  $("#titulo-vino").textContent = `Edición del vino ${cod}`;
  $("#borrar-vino").classList.remove("oculto");
}

$("#agregar-cepa").addEventListener("click", () => filaCepa());
$("#tabla-composicion").addEventListener("click", (e) => {
  if (e.target.classList.contains("quitar")) e.target.closest("tr").remove();
});
$("#nuevo-vino").addEventListener("click", limpiarVino);

$("#form-vino").addEventListener("submit", intentar(async (e) => {
  e.preventDefault();
  const f = e.target;
  // No se valida que sume 100: eso lo controla la base (RN-05) y se muestra su error.
  const cuerpo = {
    nombre: f.nombre.value, tipo: f.tipo.value, anada: Number(f.anada.value),
    volumen_ml: Number(f.volumen_ml.value), graduacion: f.graduacion.value, precio: f.precio.value,
    cuit_bodega: f.cuit_bodega.value,
    composicion: $$("#tabla-composicion tbody tr").map((tr) => ({
      id_cepa: Number($(".cepa", tr).value), porcentaje: $(".porcentaje", tr).value || 0 })),
    maridajes: $$("#lista-maridajes input:checked").map((i) => Number(i.value)),
  };
  const v = f.cod_vino.value
    ? await API.put(`/vinos/${f.cod_vino.value}`, cuerpo)
    : await API.post("/vinos", cuerpo);
  mostrar(`Vino ${v.cod_vino} guardado.`);
  await editarVino(v.cod_vino);
}));

$("#borrar-vino").addEventListener("click", intentar(async () => {
  const cod = $("#form-vino").cod_vino.value;
  await API.del(`/vinos/${cod}`);   // RN-14: si tiene movimientos, la API devuelve 409
  mostrar(`Vino ${cod} borrado.`);
  limpiarVino();
}));

// ================================================================ 3. NUEVA VENTA
const venta = { renglones: [] };

async function buscarClientes() {
  const r = await API.get("/clientes", { q: $("#buscar-cliente").value, tamanio: 20 });
  $("#combo-clientes").innerHTML = r.datos.map((c) =>
    `<option value="${c.id_cliente}">${c.id_cliente} · ${esc(c.nombre_o_razon_social)} (${c.tipo_cliente})</option>`).join("");
}
async function buscarVinos() {
  const r = await API.get("/vinos", { nombre: $("#buscar-vino").value, tamanio: 30 });
  $("#combo-vinos").innerHTML = r.datos.map((v) =>
    `<option value="${v.cod_vino}">${v.cod_vino} · ${esc(v.nombre)} ${v.anada} ${v.volumen_ml} ml</option>`).join("");
}
function dibujarRenglonesVenta() {
  $("#tabla-renglones-venta tbody").innerHTML = venta.renglones.map((r, i) => `
    <tr><td>${r.cod_vino}</td><td>${esc(r.texto)}</td><td>${r.cantidad}</td>
        <td><button data-quitar="${i}">✕</button></td></tr>`).join("");
}

let demora;
$("#buscar-cliente").addEventListener("input", () => { clearTimeout(demora); demora = setTimeout(intentar(buscarClientes), 300); });
$("#buscar-vino").addEventListener("input", () => { clearTimeout(demora); demora = setTimeout(intentar(buscarVinos), 300); });
$("#agregar-renglon").addEventListener("click", () => {
  const sel = $("#combo-vinos");
  if (!sel.value) return mostrar("Elegí un vino", "error");
  venta.renglones.push({ cod_vino: Number(sel.value), cantidad: Number($("#venta-cantidad").value),
                         texto: sel.selectedOptions[0].textContent });
  dibujarRenglonesVenta();
});
$("#tabla-renglones-venta").addEventListener("click", (e) => {
  if (e.target.dataset.quitar !== undefined) { venta.renglones.splice(e.target.dataset.quitar, 1); dibujarRenglonesVenta(); }
});

$("#confirmar-venta").addEventListener("click", intentar(async () => {
  const c = await API.post("/comprobantes", {
    id_cliente: Number($("#combo-clientes").value), id_sala: Number($("#venta-sala").value),
    renglones: venta.renglones.map(({ cod_vino, cantidad }) => ({ cod_vino, cantidad })),
  });
  // Todo lo que se muestra acá lo calculó la base.
  $("#resultado-venta").innerHTML = `
    <h3>Comprobante ${c.nro_comprobante}</h3>
    <p>${esc(c.cliente)} (${c.tipo_cliente}) · sala ${c.id_sala} · ${new Date(c.fecha).toLocaleString("es-AR")}</p>
    <table><thead><tr><th>Vino</th><th>Cant.</th><th>Precio</th><th>Desc. %</th><th>Subtotal</th></tr></thead><tbody>
    ${c.renglones.map((r) => `<tr><td>${esc(r.nombre)} ${r.anada}</td><td>${r.cantidad}</td>
      <td class="num">${pesos(r.precio_unitario)}</td><td>${r.descuento_aplicado}</td><td class="num">${pesos(r.subtotal)}</td></tr>`).join("")}
    </tbody></table>
    <p>Subtotal ${pesos(c.subtotal)} · Descuento ${pesos(c.descuento)} · <strong>Total ${pesos(c.total)}</strong></p>`;
  $("#resultado-venta").classList.remove("oculto");
  venta.renglones = []; dibujarRenglonesVenta();
  mostrar(`Venta registrada: comprobante ${c.nro_comprobante}`);
}));

// ============================================================= 4. TRANSFERENCIAS
let transfActual = null;

async function cargarTransferencias() {
  const r = await API.get("/transferencias", { estado: $("#transf-filtro").value, tamanio: 25 });
  $("#tabla-transf tbody").innerHTML = r.datos.map((t) => `
    <tr data-nro="${t.nro_transferencia}" class="clic ${transfActual === t.nro_transferencia ? "sel" : ""}">
      <td>${t.nro_transferencia}</td><td>${t.id_sala}</td><td>${t.fecha_confeccion}</td>
      <td><span class="estado ${t.estado}">${t.estado}</span></td><td>${t.botellas}</td></tr>`).join("");
}

async function verTransferencia(nro) {
  const t = await API.get(`/transferencias/${nro}`);
  transfActual = t.nro_transferencia;
  $("#detalle-transf").classList.remove("oculto");
  $("#transf-titulo").textContent = `Transferencia ${t.nro_transferencia} → ${t.sala}`;
  $("#transf-estado").innerHTML = `<span class="estado ${t.estado}">${t.estado}</span>`;
  $("#tabla-transf-renglones tbody").innerHTML = t.renglones.map((r) => `
    <tr><td>${r.cod_vino}</td><td>${esc(r.nombre)} ${r.anada}</td><td>${r.cantidad}</td><td>${r.stock_deposito}</td></tr>`).join("")
    || `<tr><td colspan="4">Sin renglones</td></tr>`;
  // Botones habilitados según el estado actual (la base igual lo controla).
  const enConfeccion = t.estado === "en_confeccion";
  $$("#transf-carga input, #transf-carga button").forEach((x) => { x.disabled = !enConfeccion; });
  $("#transf-terminar").disabled = !enConfeccion;
  $("#transf-procesar").disabled = t.estado !== "terminado";
  await cargarTransferencias();
}

$("#transf-filtro").addEventListener("change", intentar(cargarTransferencias));
$("#tabla-transf").addEventListener("click", intentar(async (e) => {
  const tr = e.target.closest("tr[data-nro]");
  if (tr) await verTransferencia(Number(tr.dataset.nro));
}));
$("#crear-transf").addEventListener("click", intentar(async () => {
  const t = await API.post("/transferencias", { id_sala: Number($("#transf-sala").value) });
  mostrar(`Transferencia ${t.nro_transferencia} creada`);
  await verTransferencia(t.nro_transferencia);
}));
$("#transf-agregar").addEventListener("click", intentar(async () => {
  await API.post(`/transferencias/${transfActual}/renglones`, {
    cod_vino: Number($("#transf-vino").value), cantidad: Number($("#transf-cantidad").value) });
  await verTransferencia(transfActual);
}));
$("#transf-terminar").addEventListener("click", intentar(async () => {
  await API.post(`/transferencias/${transfActual}/terminar`);
  mostrar("Transferencia terminada");
  await verTransferencia(transfActual);
}));
$("#transf-procesar").addEventListener("click", intentar(async () => {
  await API.post(`/transferencias/${transfActual}/procesar`);
  mostrar("Transferencia procesada: stock movido del depósito a la sala");
  await verTransferencia(transfActual);
}));

// ===================================================================== 5. TABLERO
async function cargarTablero() {
  const [top, ventas] = await Promise.all([API.get("/reportes/top-vinos", { limite: 10 }),
                                           API.get("/reportes/ventas-por-sala", { meses: 3 })]);
  $("#tabla-top tbody").innerHTML = top.map((v, i) =>
    `<tr><td>${i + 1}</td><td>${esc(v.nombre)}</td><td>${v.anada}</td><td class="num">${v.botellas_vendidas}</td></tr>`).join("");
  dibujarBarras(ventas);
  await cargarSinStock();
}

// Gráfico de barras horizontales en SVG (escala solo visual; los montos vienen de la API).
function dibujarBarras(filas) {
  const alto = 22, ancho = 640, etiqueta = 250;
  const max = Math.max(...filas.map((f) => Number(f.monto_total)), 1);
  const barras = filas.map((f, i) => {
    const w = (Number(f.monto_total) / max) * (ancho - etiqueta - 110);
    return `<text x="${etiqueta - 6}" y="${i * alto + 15}" text-anchor="end">${esc(f.sala)}</text>
            <rect x="${etiqueta}" y="${i * alto + 4}" width="${w}" height="${alto - 8}" rx="3"></rect>
            <text x="${etiqueta + w + 6}" y="${i * alto + 15}" class="valor">${pesos(f.monto_total)}</text>`;
  }).join("");
  $("#grafico-ventas").innerHTML =
    `<svg viewBox="0 0 ${ancho} ${filas.length * alto + 4}" class="barras" role="img" aria-label="Ventas por sala">${barras}</svg>`;
}

async function cargarSinStock() {
  const filas = await API.get("/reportes/vinos-sin-stock", { id_sala: $("#tablero-sala").value });
  $("#tabla-sin-stock tbody").innerHTML = filas.slice(0, 50).map((v) =>
    `<tr><td>${v.cod_vino}</td><td>${esc(v.nombre)}</td><td>${v.anada}</td><td class="num">${v.stock_deposito}</td></tr>`).join("")
    || `<tr><td colspan="4">La sala tiene stock de todos los vinos disponibles</td></tr>`;
}
$("#tablero-sala").addEventListener("change", intentar(cargarSinStock));

// ===================================================================== inicio
document.addEventListener("DOMContentLoaded", intentar(async () => {
  try {
    const s = await API.get("/salud");
    $("#estado-api").textContent = `API: ok (${s.usuario})`;
    $("#estado-api").className = "ok";
  } catch (e) {
    $("#estado-api").textContent = "API: sin conexión";
    $("#estado-api").className = "error";
    throw e;
  }
  await cargarCombos();
  limpiarVino();
  await Promise.all([cargarCatalogo(), buscarClientes(), buscarVinos()]);
}));
