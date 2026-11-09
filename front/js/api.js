// Capa única de acceso a la API: todas las llamadas pasan por acá.
// El front NO calcula importes, descuentos ni stock: solo muestra lo que
// devuelve el backend, incluidos los mensajes de error de las reglas.
const API = (() => {
  const base = () => window.CONFIG.API_URL.replace(/\/$/, "");

  async function pedir(metodo, ruta, cuerpo, params) {
    const url = new URL(base() + ruta);
    Object.entries(params || {}).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== "") url.searchParams.set(k, v);
    });
    const resp = await fetch(url, {
      method: metodo,
      headers: cuerpo ? { "Content-Type": "application/json" } : {},
      body: cuerpo ? JSON.stringify(cuerpo) : undefined,
    });
    if (resp.status === 204) return null;
    const datos = await resp.json().catch(() => ({}));
    if (!resp.ok) {
      const err = new Error(mensajeDeError(resp.status, datos));
      err.status = resp.status;
      err.datos = datos;
      throw err;
    }
    return datos;
  }

  // Se muestra el mensaje tal como lo devuelve la API (regla de la base).
  function mensajeDeError(status, d) {
    if (d.mensaje) return `${status} · ${d.mensaje}` + (d.sqlstate ? ` [SQLSTATE ${d.sqlstate}]` : "");
    if (Array.isArray(d.detail)) return `${status} · Datos inválidos: ` + d.detail.map(x => x.loc.slice(1).join(".") + " " + x.msg).join("; ");
    if (d.detail) return `${status} · ${d.detail}`;
    return `${status} · Error`;
  }

  return {
    get: (ruta, params) => pedir("GET", ruta, null, params),
    post: (ruta, cuerpo) => pedir("POST", ruta, cuerpo || null),
    put: (ruta, cuerpo) => pedir("PUT", ruta, cuerpo),
    del: (ruta) => pedir("DELETE", ruta),
  };
})();
