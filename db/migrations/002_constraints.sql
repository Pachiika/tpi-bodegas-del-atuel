-- =====================================================================
-- 002_constraints.sql  ·  Bodegas del Atuel
-- Etapa 2: restricciones UNIQUE, CHECK y DEFAULT que completan el DDL.
-- Cada restricción tiene nombre para que el error que llega a la API
-- (y al front) diga claramente qué se violó.
-- Ninguna CHECK usa funciones no determinísticas (CURRENT_DATE, now()):
-- las reglas que dependen de la fecha actual están en triggers.
-- =====================================================================

-- ---------------------------------------------------------------------
-- UNIQUE (adicionales a las claves primarias)
-- ---------------------------------------------------------------------
ALTER TABLE cepa         ADD CONSTRAINT uq_cepa_nombre          UNIQUE (nombre);
ALTER TABLE departamento ADD CONSTRAINT uq_departamento         UNIQUE (nombre, provincia);
ALTER TABLE bodega       ADD CONSTRAINT uq_bodega_razon_social  UNIQUE (razon_social);
ALTER TABLE maridaje     ADD CONSTRAINT uq_maridaje_nombre      UNIQUE (nombre);
ALTER TABLE transportista ADD CONSTRAINT uq_transportista_cuit  UNIQUE (cuit);
-- RN-04: una parcela se cosecha como máximo una vez por campaña.
ALTER TABLE lote_uva     ADD CONSTRAINT uq_lote_parcela_campania UNIQUE (id_finca, nro_parcela, campania);
-- Un mismo vino no se repite con igual nombre, añada y presentación.
ALTER TABLE vino         ADD CONSTRAINT uq_vino_nombre_anada_volumen UNIQUE (nombre, anada, volumen_ml);
-- Un documento identifica a un único cliente.
ALTER TABLE cliente      ADD CONSTRAINT uq_cliente_documento    UNIQUE (tipo_doc, nro_doc);
-- Necesaria para que los subtipos referencien (id_cliente, tipo_cliente).
ALTER TABLE cliente      ADD CONSTRAINT uq_cliente_id_tipo      UNIQUE (id_cliente, tipo_cliente);
ALTER TABLE distribuidor ADD CONSTRAINT uq_distribuidor_habilitacion UNIQUE (nro_habilitacion);

-- ---------------------------------------------------------------------
-- Jerarquía de clientes: el subtipo debe coincidir con el tipo del cliente
-- ---------------------------------------------------------------------
ALTER TABLE distribuidor
    ADD CONSTRAINT ck_distribuidor_tipo CHECK (tipo_cliente = 'distribuidor'),
    ALTER COLUMN tipo_cliente SET DEFAULT 'distribuidor',
    ADD CONSTRAINT fk_distribuidor_cliente FOREIGN KEY (id_cliente, tipo_cliente)
        REFERENCES cliente (id_cliente, tipo_cliente) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE exportador
    ADD CONSTRAINT ck_exportador_tipo CHECK (tipo_cliente = 'exportador'),
    ALTER COLUMN tipo_cliente SET DEFAULT 'exportador',
    ADD CONSTRAINT fk_exportador_cliente FOREIGN KEY (id_cliente, tipo_cliente)
        REFERENCES cliente (id_cliente, tipo_cliente) ON DELETE CASCADE ON UPDATE CASCADE;

-- ---------------------------------------------------------------------
-- CHECK  (RN-01, RN-06, RN-07, RN-09, RN-15 y validaciones de formato)
-- ---------------------------------------------------------------------
-- RN-01 / RN-15: precio positivo, graduación entre 5 y 20.
ALTER TABLE vino ADD CONSTRAINT ck_vino_precio_positivo CHECK (precio > 0);
ALTER TABLE vino ADD CONSTRAINT ck_vino_graduacion      CHECK (graduacion BETWEEN 5 AND 20);
ALTER TABLE vino ADD CONSTRAINT ck_vino_volumen         CHECK (volumen_ml IN (187, 375, 750, 1500, 3000));
ALTER TABLE vino ADD CONSTRAINT ck_vino_anada           CHECK (anada BETWEEN 1990 AND 2100);

-- RN-05 (parcial): cada porcentaje de corte es mayor que 0.
-- La suma = 100 la controla un constraint trigger diferido (005).
ALTER TABLE composicion_vino ADD CONSTRAINT ck_composicion_porcentaje CHECK (porcentaje > 0);

-- RN-15: superficies, kilos y cantidades positivas.
ALTER TABLE finca    ADD CONSTRAINT ck_finca_superficie   CHECK (superficie_ha > 0);
ALTER TABLE parcela  ADD CONSTRAINT ck_parcela_superficie CHECK (superficie_ha > 0);
ALTER TABLE parcela  ADD CONSTRAINT ck_parcela_anio       CHECK (anio_plantacion BETWEEN 1900 AND 2100);
ALTER TABLE lote_uva ADD CONSTRAINT ck_lote_kilos         CHECK (kilos_cosechados > 0);
-- CHECK entre columnas: la fecha de cosecha pertenece al año de la campaña.
ALTER TABLE lote_uva ADD CONSTRAINT ck_lote_fecha_campania
    CHECK (EXTRACT(YEAR FROM fecha_cosecha) = campania);

ALTER TABLE analisis_calidad ADD CONSTRAINT ck_analisis_brix    CHECK (grado_brix BETWEEN 0 AND 40);
ALTER TABLE analisis_calidad ADD CONSTRAINT ck_analisis_ph      CHECK (ph BETWEEN 2 AND 5);
ALTER TABLE analisis_calidad ADD CONSTRAINT ck_analisis_acidez  CHECK (acidez_total > 0);

ALTER TABLE maridaje ADD CONSTRAINT ck_maridaje_temperatura CHECK (temperatura_servicio BETWEEN 2 AND 25);

ALTER TABLE empleado ADD CONSTRAINT ck_empleado_salario CHECK (salario > 0);

-- RN-06: el descuento del cliente está en un rango válido (la U6 lo lleva a 35 %).
ALTER TABLE cliente ADD CONSTRAINT ck_cliente_descuento CHECK (descuento BETWEEN 0 AND 50);
ALTER TABLE cliente ADD CONSTRAINT ck_cliente_tipo_doc  CHECK (tipo_doc IN ('DNI', 'CUIT', 'PASAPORTE'));

-- RN-07: CHECK entre columnas, el vencimiento es posterior a la emisión.
ALTER TABLE permiso_exportacion ADD CONSTRAINT ck_permiso_fechas
    CHECK (fecha_vencimiento > fecha_emision);

-- RN-08: el total es siempre subtotal menos descuento (CHECK entre columnas).
ALTER TABLE comprobante ADD CONSTRAINT ck_comprobante_total
    CHECK (total = subtotal - descuento);

-- RN-15: cantidades y precios positivos en los renglones.
ALTER TABLE renglon_comprobante   ADD CONSTRAINT ck_rc_cantidad CHECK (cantidad > 0);
ALTER TABLE renglon_comprobante   ADD CONSTRAINT ck_rc_precio   CHECK (precio_unitario > 0);
ALTER TABLE renglon_ingreso       ADD CONSTRAINT ck_ri_cantidad CHECK (cantidad > 0);
ALTER TABLE renglon_transferencia ADD CONSTRAINT ck_rt_cantidad CHECK (cantidad > 0);

-- RN-09: el stock nunca es negativo.
ALTER TABLE stock_sala     ADD CONSTRAINT ck_stock_sala_no_negativo     CHECK (cantidad >= 0);
ALTER TABLE stock_deposito ADD CONSTRAINT ck_stock_deposito_no_negativo CHECK (cantidad >= 0);

-- Formato mínimo de e-mail del transportista.
ALTER TABLE transportista ADD CONSTRAINT ck_transportista_email
    CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$');

-- ---------------------------------------------------------------------
-- DEFAULT
-- ---------------------------------------------------------------------
ALTER TABLE ingreso       ALTER COLUMN estado SET DEFAULT 'en_confeccion';
ALTER TABLE ingreso       ALTER COLUMN fecha  SET DEFAULT CURRENT_DATE;
ALTER TABLE transferencia ALTER COLUMN estado SET DEFAULT 'en_confeccion';
ALTER TABLE transferencia ALTER COLUMN fecha_confeccion SET DEFAULT CURRENT_DATE;
ALTER TABLE cliente       ALTER COLUMN fecha_alta SET DEFAULT CURRENT_DATE;
ALTER TABLE comprobante   ALTER COLUMN fecha     SET DEFAULT now();
ALTER TABLE comprobante   ALTER COLUMN subtotal  SET DEFAULT 0;
ALTER TABLE comprobante   ALTER COLUMN descuento SET DEFAULT 0;
ALTER TABLE comprobante   ALTER COLUMN total     SET DEFAULT 0;
ALTER TABLE stock_sala    ALTER COLUMN cantidad  SET DEFAULT 0;
ALTER TABLE stock_deposito ALTER COLUMN cantidad SET DEFAULT 0;
ALTER TABLE auditoria_precio ALTER COLUMN fecha_hora SET DEFAULT now();
ALTER TABLE auditoria_precio ALTER COLUMN usuario    SET DEFAULT session_user;
