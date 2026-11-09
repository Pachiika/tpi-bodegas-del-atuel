"""Pruebas automáticas de la API (pytest).

Las marcadas con "REGLA" provocan a propósito la violación de una regla de
la base y verifican que la API devuelva el código HTTP de la tabla de
traducción de SQLSTATE y que no queden datos a medias.
"""
import pytest


def _vino(datos, **cambios):
    v = {"nombre": f"Vino Prueba {datos['sufijo']}", "tipo": "tinto", "anada": 2022,
         "volumen_ml": 750, "graduacion": 14, "precio": 10000, "cuit_bodega": datos["cuit_bodega"],
         "composicion": [{"id_cepa": datos["cepa1"], "porcentaje": 85},
                         {"id_cepa": datos["cepa2"], "porcentaje": 15}],
         "maridajes": []}
    v.update(cambios)
    return v


@pytest.fixture(scope="module")
def vino(cliente_http, datos, conexion):
    """Vino de prueba con stock: 10 en la sala de prueba y 100 en depósito."""
    r = cliente_http.post("/vinos", json=_vino(datos))
    assert r.status_code == 201, r.text
    cod = r.json()["cod_vino"]
    conexion.execute("INSERT INTO stock_sala (id_sala, cod_vino, cantidad) VALUES (%s, %s, 10)",
                     (datos["id_sala"], cod))
    conexion.execute("INSERT INTO stock_deposito (cod_vino, cantidad) VALUES (%s, 100)", (cod,))
    return cod


@pytest.fixture(scope="module")
def socio(cliente_http, datos):
    r = cliente_http.post("/clientes", json={
        "nombre_o_razon_social": f"Socio Prueba {datos['sufijo']}", "tipo_doc": "DNI",
        "nro_doc": "9" + datos["sufijo"], "direccion": "San Martín 100",
        "cp_localidad": datos["cp"], "tipo_cliente": "socio"})
    assert r.status_code == 201, r.text
    return r.json()


# ----------------------------------------------------------------- funcionamiento
def test_salud_usa_rol_sin_privilegios(cliente_http):
    r = cliente_http.get("/salud")
    assert r.status_code == 200
    cuerpo = r.json()
    assert cuerpo["es_superusuario"] is False
    assert cuerpo["puede_escribir_auditoria"] is False   # app_rw no puede falsear la auditoría


def test_catalogo_filtros_y_paginacion(cliente_http, datos, vino):
    r = cliente_http.get("/vinos", params={"bodega": datos["cuit_bodega"], "tipo": "tinto",
                                           "cepa": f"CepaA {datos['sufijo']}", "anada": 2022,
                                           "pagina": 1, "tamanio": 5})
    assert r.status_code == 200
    cuerpo = r.json()
    assert cuerpo["total"] == 1 and cuerpo["datos"][0]["cod_vino"] == vino
    assert cliente_http.get("/vinos", params={"tamanio": 1000}).status_code == 422  # tope de página


def test_ficha_vino_con_composicion(cliente_http, vino):
    r = cliente_http.get(f"/vinos/{vino}")
    assert r.status_code == 200
    assert sorted(c["porcentaje"] for c in r.json()["composicion"]) == [15, 85]
    assert cliente_http.get("/vinos/999999999").status_code == 404


def test_inyeccion_sql_se_trata_como_texto(cliente_http):
    malicioso = "x'; DROP TABLE vino; --"
    r = cliente_http.get("/vinos", params={"nombre": malicioso})
    assert r.status_code == 200 and r.json()["total"] == 0
    assert cliente_http.get("/vinos", params={"tamanio": 1}).json()["total"] > 0  # la tabla sigue


def test_cliente_recibe_descuento_de_la_base(socio):
    # La API no envió descuento: lo asignó el trigger según el tipo (RN-06).
    assert socio["descuento"] is not None and socio["tipo_cliente"] == "socio"


def test_venta_ok_calcula_la_base_y_descuenta_stock(cliente_http, datos, vino, socio, conexion):
    r = cliente_http.post("/comprobantes", json={"id_cliente": socio["id_cliente"], "id_sala": datos["id_sala"],
                                                 "renglones": [{"cod_vino": vino, "cantidad": 2}]})
    assert r.status_code == 201, r.text
    comp = r.json()
    esperado_subtotal = 2 * 10000
    assert comp["subtotal"] == esperado_subtotal
    assert comp["total"] == pytest.approx(esperado_subtotal * (1 - socio["descuento"] / 100))
    stock = conexion.execute("SELECT cantidad FROM stock_sala WHERE id_sala=%s AND cod_vino=%s",
                             (datos["id_sala"], vino)).fetchone()["cantidad"]
    assert stock == 8


def test_cambio_de_precio_queda_auditado(cliente_http, datos, vino):
    r = cliente_http.put(f"/vinos/{vino}", json={k: v for k, v in _vino(datos, precio=11000).items()
                                                 if k not in ("composicion", "maridajes")})
    assert r.status_code == 200 and r.json()["precio"] == 11000
    aud = cliente_http.get(f"/vinos/{vino}/auditoria-precio").json()
    assert aud[0]["precio_anterior"] == 10000 and aud[0]["precio_nuevo"] == 11000
    assert aud[0]["usuario"]  # quién lo cambió (session_user)


def test_circuito_transferencia(cliente_http, datos, vino, conexion):
    t = cliente_http.post("/transferencias", json={"id_sala": datos["id_sala"]}).json()
    assert t["estado"] == "en_confeccion"
    nro = t["nro_transferencia"]
    assert cliente_http.post(f"/transferencias/{nro}/renglones", json={"cod_vino": vino, "cantidad": 5}).status_code == 200
    assert cliente_http.post(f"/transferencias/{nro}/terminar").json()["estado"] == "terminado"
    assert cliente_http.post(f"/transferencias/{nro}/procesar").json()["estado"] == "procesado"
    dep = conexion.execute("SELECT cantidad FROM stock_deposito WHERE cod_vino=%s", (vino,)).fetchone()
    assert dep["cantidad"] == 95


# --------------------------------------------------- REGLA: violaciones a propósito
def test_REGLA_venta_sin_stock_409_y_sin_datos_a_medias(cliente_http, datos, vino, socio, conexion):
    antes = conexion.execute("SELECT count(*) AS n FROM comprobante WHERE id_sala=%s",
                             (datos["id_sala"],)).fetchone()["n"]
    r = cliente_http.post("/comprobantes", json={"id_cliente": socio["id_cliente"], "id_sala": datos["id_sala"],
                                                 "renglones": [{"cod_vino": vino, "cantidad": 1000}]})
    assert r.status_code == 409
    assert r.json()["sqlstate"] == "P0001" and "Stock insuficiente" in r.json()["mensaje"]
    despues = conexion.execute("SELECT count(*) AS n FROM comprobante WHERE id_sala=%s",
                               (datos["id_sala"],)).fetchone()["n"]
    assert despues == antes   # el ROLLBACK deshizo también la cabecera


def test_REGLA_precio_negativo_422(cliente_http, datos):
    r = cliente_http.post("/vinos", json=_vino(datos, nombre="Precio negativo", precio=-5))
    assert r.status_code == 422
    assert r.json()["sqlstate"] == "23514" and r.json()["restriccion"] == "ck_vino_precio_positivo"


def test_REGLA_composicion_que_no_suma_100(cliente_http, datos):
    nombre = f"Corte mal {datos['sufijo']}"
    r = cliente_http.post("/vinos", json=_vino(datos, nombre=nombre, composicion=[
        {"id_cepa": datos["cepa1"], "porcentaje": 60}, {"id_cepa": datos["cepa2"], "porcentaje": 30}]))
    assert r.status_code == 409 and "100" in r.json()["mensaje"]
    assert cliente_http.get("/vinos", params={"nombre": nombre}).json()["total"] == 0  # no quedó el vino


def test_REGLA_cambio_de_estado_invalido(cliente_http, datos):
    nro = cliente_http.post("/transferencias", json={"id_sala": datos["id_sala"]}).json()["nro_transferencia"]
    r = cliente_http.post(f"/transferencias/{nro}/terminar")      # sin renglones
    assert r.status_code == 409 and r.json()["sqlstate"] == "P0001"
    r = cliente_http.post(f"/transferencias/{nro}/procesar")      # en confección
    assert r.status_code == 409


def test_REGLA_renglon_en_documento_procesado(cliente_http, datos, vino):
    nro = cliente_http.post("/transferencias", json={"id_sala": datos["id_sala"]}).json()["nro_transferencia"]
    cliente_http.post(f"/transferencias/{nro}/renglones", json={"cod_vino": vino, "cantidad": 1})
    cliente_http.post(f"/transferencias/{nro}/terminar")
    r = cliente_http.post(f"/transferencias/{nro}/renglones", json={"cod_vino": vino, "cantidad": 1})
    assert r.status_code == 409   # RN-12


def test_REGLA_borrar_vino_con_movimientos_409(cliente_http, vino):
    r = cliente_http.delete(f"/vinos/{vino}")
    assert r.status_code == 409 and r.json()["sqlstate"] in ("23503", "23001")   # 23001 en PostgreSQL 17+


def test_REGLA_documento_duplicado_409(cliente_http, datos, socio):
    r = cliente_http.post("/clientes", json={
        "nombre_o_razon_social": "Duplicado", "tipo_doc": "DNI", "nro_doc": socio["nro_doc"],
        "direccion": "X 1", "cp_localidad": datos["cp"], "tipo_cliente": "socio"})
    assert r.status_code == 409 and r.json()["sqlstate"] == "23505"


def test_REGLA_estado_invalido_400(cliente_http):
    # el estado es un ENUM: un valor que no existe da 22P02
    r = cliente_http.get("/transferencias", params={"estado": "violeta"})
    assert r.status_code == 400 and r.json()["sqlstate"] == "22P02"


def test_REGLA_distribuidor_sin_zona_422(cliente_http, datos):
    r = cliente_http.post("/clientes", json={
        "nombre_o_razon_social": "Distribuidor incompleto", "tipo_doc": "CUIT",
        "nro_doc": "34" + datos["sufijo"] + "111", "direccion": "X 1", "cp_localidad": datos["cp"],
        "tipo_cliente": "distribuidor"})
    assert r.status_code == 422 and r.json()["restriccion"] == "ck_cliente_datos_tipo"


def test_circuito_ingreso_suma_stock_en_deposito(cliente_http, datos, vino, conexion):
    antes = conexion.execute("SELECT cantidad FROM stock_deposito WHERE cod_vino=%s", (vino,)).fetchone()["cantidad"]
    i = cliente_http.post("/ingresos", json={"codigo_transporte": datos["transporte"],
                                             "cuit_bodega": datos["cuit_bodega"]}).json()
    cod = i["codigo_ingreso"]
    cliente_http.post(f"/ingresos/{cod}/renglones", json={"cod_vino": vino, "cantidad": 30})
    cliente_http.post(f"/ingresos/{cod}/terminar")
    assert cliente_http.post(f"/ingresos/{cod}/procesar").json()["estado"] == "procesado"
    despues = conexion.execute("SELECT cantidad FROM stock_deposito WHERE cod_vino=%s", (vino,)).fetchone()["cantidad"]
    assert despues == antes + 30


def test_alta_exportador(cliente_http, datos):
    r = cliente_http.post("/clientes", json={
        "nombre_o_razon_social": f"Export Prueba {datos['sufijo']}", "tipo_doc": "CUIT",
        "nro_doc": "33" + datos["sufijo"] + "999", "direccion": "Ruta 7", "cp_localidad": datos["cp"],
        "tipo_cliente": "exportador", "pais_destino_principal": "Brasil"})
    assert r.status_code == 201, r.text
    assert r.json()["pais_destino_principal"] == "Brasil"
    assert cliente_http.delete(f"/clientes/{r.json()['id_cliente']}").status_code == 204
