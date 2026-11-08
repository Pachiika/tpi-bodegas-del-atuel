-- =============================================
-- 001_esquema.sql
-- Crea los tipos, los dominios y todas las tablas con sus claves
-- primarias y foraneas (segun el modelo del grupo).
-- Las restricciones UNIQUE, CHECK y DEFAULT estan en 002_constraints.sql
-- =============================================


-- ---------- Tipo ENUM ----------
-- El estado de ingresos y transferencias solo puede tomar estos 3 valores.
-- (El enunciado pide que el estado sea un tipo ENUM.)
CREATE TYPE estado_documento AS ENUM ('en_confeccion', 'terminado', 'procesado');


-- ---------- Dominios ----------
-- Un dominio es un tipo de dato con una condicion ya incluida.

-- CUIT: 11 numeros
CREATE DOMAIN cuit_dom AS VARCHAR(11)
    CHECK (VALUE ~ '^[0-9]{11}$');

-- Importes de dinero: no pueden ser negativos
CREATE DOMAIN dinero_dom AS NUMERIC(12,2)
    CHECK (VALUE >= 0);

-- Porcentajes: entre 0 y 100
CREATE DOMAIN porcentaje_dom AS NUMERIC(5,2)
    CHECK (VALUE BETWEEN 0 AND 100);


-- ---------- Localidades, salas y empleados ----------

CREATE TABLE localidad (
    codigo_postal      VARCHAR(10) PRIMARY KEY,
    nombre             VARCHAR(80) NOT NULL,
    provincia          VARCHAR(80) NOT NULL,
    encargado_regional VARCHAR(120) NOT NULL   -- RN-02: un encargado por localidad
);

CREATE TABLE sala_venta (
    id_sala      SERIAL PRIMARY KEY,
    calle        VARCHAR(80) NOT NULL,
    numero       VARCHAR(10) NOT NULL,
    dia_cierre   VARCHAR(15) NOT NULL,
    cp_localidad VARCHAR(10) NOT NULL
        REFERENCES localidad (codigo_postal) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE empleado (
    cuit          cuit_dom PRIMARY KEY,
    nombre        VARCHAR(120) NOT NULL,
    fecha_ingreso DATE NOT NULL,
    salario       NUMERIC(10,2) NOT NULL,
    id_sala       INT NOT NULL                  -- RN-03: trabaja en una sola sala
        REFERENCES sala_venta (id_sala) ON DELETE RESTRICT ON UPDATE CASCADE
);


-- ---------- Fincas, parcelas, lotes y analisis ----------

CREATE TABLE cepa (
    id_cepa SERIAL PRIMARY KEY,
    nombre  VARCHAR(50) NOT NULL,
    tipo    VARCHAR(20) NOT NULL                -- tinta o blanca
);

CREATE TABLE finca (
    id_finca      SERIAL PRIMARY KEY,
    nombre        VARCHAR(80) NOT NULL,
    superficie_ha NUMERIC(8,2) NOT NULL,
    departamento  VARCHAR(80) NOT NULL,
    provincia     VARCHAR(80) NOT NULL
);

-- Parcela es una entidad debil: depende de la finca.
-- Su clave es (id_finca, nro_parcela).
CREATE TABLE parcela (
    id_finca        INT NOT NULL
        REFERENCES finca (id_finca) ON DELETE CASCADE ON UPDATE CASCADE,
    nro_parcela     INT NOT NULL,
    superficie_ha   NUMERIC(8,2) NOT NULL,
    anio_plantacion INT NOT NULL,
    id_cepa         INT NOT NULL                -- RN-04: una sola cepa por parcela
        REFERENCES cepa (id_cepa) ON DELETE RESTRICT ON UPDATE CASCADE,
    PRIMARY KEY (id_finca, nro_parcela)
);

CREATE TABLE bodega (
    cuit         cuit_dom PRIMARY KEY,
    razon_social VARCHAR(120) NOT NULL,
    domicilio    VARCHAR(150) NOT NULL
);

CREATE TABLE lote_uva (
    nro_lote            SERIAL PRIMARY KEY,
    id_finca            INT NOT NULL,
    nro_parcela         INT NOT NULL,
    campania            INT NOT NULL,
    fecha_cosecha       DATE NOT NULL,
    kilos_cosechados    NUMERIC(10,2) NOT NULL,
    cuit_bodega_destino cuit_dom NOT NULL
        REFERENCES bodega (cuit) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (id_finca, nro_parcela)
        REFERENCES parcela (id_finca, nro_parcela) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE analisis_calidad (
    id_analisis  SERIAL PRIMARY KEY,
    nro_lote     INT NOT NULL
        REFERENCES lote_uva (nro_lote) ON DELETE CASCADE ON UPDATE CASCADE,
    fecha        DATE NOT NULL,
    grado_brix   NUMERIC(5,2) NOT NULL,
    ph           NUMERIC(4,2) NOT NULL,
    acidez_total NUMERIC(5,2) NOT NULL
);


-- ---------- Vinos, cortes y maridajes ----------

CREATE TABLE vino (
    cod_vino    SERIAL PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL,
    tipo        VARCHAR(20) NOT NULL,           -- tinto, blanco, rosado o espumante
    anada       INT NOT NULL,
    volumen_ml  INT NOT NULL,
    graduacion  NUMERIC(4,2) NOT NULL,
    precio      NUMERIC(10,2) NOT NULL,         -- RN-01: el mismo precio en toda la red
    cuit_bodega cuit_dom NOT NULL
        REFERENCES bodega (cuit) ON DELETE RESTRICT ON UPDATE CASCADE      -- RN-14
);

-- Relacion N:M entre vino y cepa, con el porcentaje de cada cepa en el corte
CREATE TABLE composicion_vino (
    cod_vino   INT NOT NULL
        REFERENCES vino (cod_vino) ON DELETE CASCADE ON UPDATE CASCADE,
    id_cepa    INT NOT NULL
        REFERENCES cepa (id_cepa) ON DELETE RESTRICT ON UPDATE CASCADE,
    porcentaje INT NOT NULL,
    PRIMARY KEY (cod_vino, id_cepa)
);

CREATE TABLE maridaje (
    id_maridaje          SERIAL PRIMARY KEY,
    nombre               VARCHAR(80) NOT NULL,
    temperatura_servicio INT NOT NULL
);

CREATE TABLE vino_maridaje (
    cod_vino    INT NOT NULL
        REFERENCES vino (cod_vino) ON DELETE CASCADE ON UPDATE CASCADE,
    id_maridaje INT NOT NULL
        REFERENCES maridaje (id_maridaje) ON DELETE RESTRICT ON UPDATE CASCADE,
    PRIMARY KEY (cod_vino, id_maridaje)
);


-- ---------- Clientes ----------
-- Jerarquia de clientes en UNA SOLA TABLA con la columna tipo_cliente.
-- Los datos propios de cada tipo quedan en NULL cuando no corresponden:
--   distribuidor -> zona_cobertura y nro_habilitacion
--   exportador   -> pais_destino_principal
-- Un CHECK en 002 controla que cada tipo tenga solo sus datos.
CREATE TABLE cliente (
    id_cliente             SERIAL PRIMARY KEY,
    nombre_o_razon_social  VARCHAR(120) NOT NULL,
    tipo_doc               VARCHAR(10) NOT NULL,
    nro_doc                VARCHAR(20) NOT NULL,
    direccion              VARCHAR(150) NOT NULL,
    cp_localidad           VARCHAR(10) NOT NULL
        REFERENCES localidad (codigo_postal) ON DELETE RESTRICT ON UPDATE CASCADE,
    fecha_alta             DATE NOT NULL,
    tipo_cliente           VARCHAR(20) NOT NULL,   -- socio, distribuidor o exportador
    descuento              porcentaje_dom NOT NULL, -- RN-06 (lo pone un trigger segun el tipo)
    zona_cobertura         VARCHAR(80),
    nro_habilitacion       VARCHAR(50),
    pais_destino_principal VARCHAR(80)
);

-- Un exportador puede tener varios permisos (RN-07)
CREATE TABLE permiso_exportacion (
    codigo            VARCHAR(30) PRIMARY KEY,
    id_cliente        INT NOT NULL
        REFERENCES cliente (id_cliente) ON DELETE CASCADE ON UPDATE CASCADE,
    fecha_emision     DATE NOT NULL,
    fecha_vencimiento DATE NOT NULL
);


-- ---------- Ventas ----------

CREATE TABLE comprobante (
    nro_comprobante SERIAL PRIMARY KEY,
    fecha           TIMESTAMP NOT NULL,
    id_cliente      INT NOT NULL
        REFERENCES cliente (id_cliente) ON DELETE RESTRICT ON UPDATE CASCADE,
    id_sala         INT NOT NULL
        REFERENCES sala_venta (id_sala) ON DELETE RESTRICT ON UPDATE CASCADE,
    subtotal        dinero_dom NOT NULL,   -- suma sin descuento
    descuento       dinero_dom NOT NULL,   -- plata descontada
    total           dinero_dom NOT NULL    -- RN-08: lo calcula la base
);

CREATE TABLE renglon_comprobante (
    nro_comprobante    INT NOT NULL
        REFERENCES comprobante (nro_comprobante) ON DELETE CASCADE ON UPDATE CASCADE,
    cod_vino           INT NOT NULL
        REFERENCES vino (cod_vino) ON DELETE RESTRICT ON UPDATE CASCADE,
    cantidad           INT NOT NULL,
    precio_unitario    NUMERIC(10,2) NOT NULL,   -- precio del vino el dia de la venta
    descuento_aplicado porcentaje_dom NOT NULL,  -- % segun el tipo de cliente
    subtotal           dinero_dom NOT NULL,
    PRIMARY KEY (nro_comprobante, cod_vino)
);


-- ---------- Stock ----------

CREATE TABLE stock_sala (
    id_sala  INT NOT NULL
        REFERENCES sala_venta (id_sala) ON DELETE RESTRICT ON UPDATE CASCADE,
    cod_vino INT NOT NULL
        REFERENCES vino (cod_vino) ON DELETE RESTRICT ON UPDATE CASCADE,
    cantidad INT NOT NULL,
    PRIMARY KEY (id_sala, cod_vino)
);

-- Hay un solo deposito central: una fila por vino
CREATE TABLE stock_deposito (
    cod_vino INT PRIMARY KEY
        REFERENCES vino (cod_vino) ON DELETE RESTRICT ON UPDATE CASCADE,
    cantidad INT NOT NULL
);


-- ---------- Transportistas, ingresos y transferencias ----------

CREATE TABLE transportista (
    codigo_transporte SERIAL PRIMARY KEY,
    razon_social      VARCHAR(120) NOT NULL,
    cuit              cuit_dom NOT NULL,
    email             VARCHAR(100) NOT NULL,
    telefono          VARCHAR(30) NOT NULL,
    domicilio         VARCHAR(150) NOT NULL
);

-- Localidades que cubre cada transportista (N:M)
CREATE TABLE transportista_cubre_localidad (
    codigo_transporte INT NOT NULL
        REFERENCES transportista (codigo_transporte) ON DELETE CASCADE ON UPDATE CASCADE,
    cp_localidad      VARCHAR(10) NOT NULL
        REFERENCES localidad (codigo_postal) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (codigo_transporte, cp_localidad)
);

CREATE TABLE ingreso (
    codigo_ingreso    SERIAL PRIMARY KEY,
    fecha             TIMESTAMP NOT NULL,
    estado            estado_documento NOT NULL,
    codigo_transporte INT NOT NULL
        REFERENCES transportista (codigo_transporte) ON DELETE RESTRICT ON UPDATE CASCADE,  -- RN-14
    cuit_bodega       cuit_dom NOT NULL
        REFERENCES bodega (cuit) ON DELETE RESTRICT ON UPDATE CASCADE                       -- RN-14
);

CREATE TABLE renglon_ingreso (
    codigo_ingreso INT NOT NULL
        REFERENCES ingreso (codigo_ingreso) ON DELETE CASCADE ON UPDATE CASCADE,
    cod_vino       INT NOT NULL
        REFERENCES vino (cod_vino) ON DELETE RESTRICT ON UPDATE CASCADE,
    cantidad       INT NOT NULL,
    PRIMARY KEY (codigo_ingreso, cod_vino)
);

CREATE TABLE transferencia (
    nro_transferencia SERIAL PRIMARY KEY,
    id_sala           INT NOT NULL
        REFERENCES sala_venta (id_sala) ON DELETE RESTRICT ON UPDATE CASCADE,
    fecha_confeccion  TIMESTAMP NOT NULL,
    estado            estado_documento NOT NULL
);

CREATE TABLE renglon_transferencia (
    nro_transferencia INT NOT NULL
        REFERENCES transferencia (nro_transferencia) ON DELETE CASCADE ON UPDATE CASCADE,
    cod_vino          INT NOT NULL
        REFERENCES vino (cod_vino) ON DELETE RESTRICT ON UPDATE CASCADE,
    cantidad          INT NOT NULL,
    PRIMARY KEY (nro_transferencia, cod_vino)
);


-- ---------- Auditoria de precios (RN-13) ----------
-- La llena un trigger cada vez que cambia el precio de un vino.
CREATE TABLE auditoria_precio (
    id_auditoria    SERIAL PRIMARY KEY,
    cod_vino        INT NOT NULL
        REFERENCES vino (cod_vino) ON DELETE RESTRICT ON UPDATE CASCADE,
    precio_anterior NUMERIC(10,2) NOT NULL,
    precio_nuevo    NUMERIC(10,2) NOT NULL,
    fecha_hora      TIMESTAMP NOT NULL,
    usuario         VARCHAR(50) NOT NULL
);


-- ---------- Descripcion de cada tabla ----------
-- (queda guardada en la base y se usa para armar el diccionario de datos)
COMMENT ON TABLE localidad IS 'Localidades de Mendoza. El encargado regional depende solo de la localidad (RN-02).';
COMMENT ON TABLE sala_venta IS 'Salas de venta; cada una en una localidad y con un dia de cierre semanal.';
COMMENT ON TABLE empleado IS 'Empleados; cada uno trabaja en una sola sala (RN-03).';
COMMENT ON TABLE cepa IS 'Cepas (variedades de uva), tintas o blancas.';
COMMENT ON TABLE finca IS 'Fincas productoras de uva, con su departamento y provincia.';
COMMENT ON TABLE parcela IS 'Entidad debil de finca: se identifica por (finca, numero de parcela); tiene una cepa.';
COMMENT ON TABLE bodega IS 'Bodegas (clave: CUIT).';
COMMENT ON TABLE lote_uva IS 'Lote cosechado en una parcela en una campaña y entregado a una bodega (RN-04).';
COMMENT ON TABLE analisis_calidad IS 'Analisis de laboratorio de un lote (grado Brix, pH, acidez).';
COMMENT ON TABLE vino IS 'Vinos. El precio es el mismo en toda la red (RN-01).';
COMMENT ON TABLE composicion_vino IS 'Corte del vino: porcentaje de cada cepa; tiene que sumar 100 (RN-05).';
COMMENT ON TABLE maridaje IS 'Comidas sugeridas con su temperatura de servicio.';
COMMENT ON TABLE vino_maridaje IS 'Relacion N:M entre vinos y maridajes.';
COMMENT ON TABLE cliente IS 'Clientes de los tres tipos en una sola tabla (socio, distribuidor, exportador). El descuento lo pone un trigger (RN-06).';
COMMENT ON TABLE permiso_exportacion IS 'Permisos de exportacion; solo para exportadores y con vencimiento posterior a la emision (RN-07).';
COMMENT ON TABLE comprobante IS 'Cabecera de una venta. Subtotal, descuento y total los calcula la base (RN-08).';
COMMENT ON TABLE renglon_comprobante IS 'Renglon de venta: guarda precio y descuento del momento; descuenta stock de la sala (RN-09).';
COMMENT ON TABLE stock_sala IS 'Stock de cada vino en cada sala; nunca negativo (RN-09).';
COMMENT ON TABLE stock_deposito IS 'Stock del deposito central; nunca negativo.';
COMMENT ON TABLE transportista IS 'Empresas de transporte que traen los ingresos.';
COMMENT ON TABLE transportista_cubre_localidad IS 'Localidades que cubre cada transportista (N:M).';
COMMENT ON TABLE ingreso IS 'Ingreso de botellas desde una bodega al deposito (en_confeccion -> terminado -> procesado, RN-10).';
COMMENT ON TABLE renglon_ingreso IS 'Vinos y cantidades de un ingreso; solo se tocan en confeccion (RN-12).';
COMMENT ON TABLE transferencia IS 'Transferencia del deposito a una sala (en_confeccion -> terminado -> procesado, RN-11).';
COMMENT ON TABLE renglon_transferencia IS 'Vinos y cantidades de una transferencia; solo se tocan en confeccion (RN-12).';
COMMENT ON TABLE auditoria_precio IS 'Historial de cambios de precio de los vinos; lo llena un trigger (RN-13).';
