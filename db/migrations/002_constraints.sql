-- =============================================
-- 002_constraints.sql
-- Restricciones: UNIQUE, CHECK y DEFAULT
-- A cada restriccion le ponemos nombre para que el
-- mensaje de error diga cual fue la que fallo.
-- =============================================


-- ---------- UNIQUE (valores que no se pueden repetir) ----------

ALTER TABLE cepa ADD CONSTRAINT uq_cepa_nombre UNIQUE (nombre);
ALTER TABLE bodega ADD CONSTRAINT uq_bodega_razon_social UNIQUE (razon_social);
ALTER TABLE maridaje ADD CONSTRAINT uq_maridaje_nombre UNIQUE (nombre);
ALTER TABLE transportista ADD CONSTRAINT uq_transportista_cuit UNIQUE (cuit);

-- RN-04: una parcela se cosecha una sola vez por campaña
ALTER TABLE lote_uva ADD CONSTRAINT uq_lote_parcela_campania UNIQUE (id_finca, nro_parcela, campania);

-- No puede haber dos vinos con el mismo nombre, añada y tamaño de botella
ALTER TABLE vino ADD CONSTRAINT uq_vino_nombre_anada_volumen UNIQUE (nombre, anada, volumen_ml);

-- Dos clientes no pueden tener el mismo documento
ALTER TABLE cliente ADD CONSTRAINT uq_cliente_documento UNIQUE (tipo_doc, nro_doc);

-- Dos distribuidores no pueden tener el mismo numero de habilitacion
-- (los NULL de los otros tipos no cuentan como repetidos)
ALTER TABLE cliente ADD CONSTRAINT uq_cliente_habilitacion UNIQUE (nro_habilitacion);


-- ---------- CHECK (condiciones que tiene que cumplir cada fila) ----------
-- Ojo: en los CHECK no usamos CURRENT_DATE porque el resultado
-- cambiaria segun el dia. Esas reglas van en triggers (005).

-- Valores permitidos en las columnas de "tipo" (lista cerrada)
ALTER TABLE cepa ADD CONSTRAINT ck_cepa_tipo CHECK (tipo IN ('tinta', 'blanca'));
ALTER TABLE vino ADD CONSTRAINT ck_vino_tipo CHECK (tipo IN ('tinto', 'blanco', 'rosado', 'espumante'));
ALTER TABLE cliente ADD CONSTRAINT ck_cliente_tipo CHECK (tipo_cliente IN ('socio', 'distribuidor', 'exportador'));
ALTER TABLE sala_venta ADD CONSTRAINT ck_sala_dia_cierre
    CHECK (dia_cierre IN ('lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'));

-- Vino (RN-01 y RN-15)
ALTER TABLE vino ADD CONSTRAINT ck_vino_precio_positivo CHECK (precio > 0);
ALTER TABLE vino ADD CONSTRAINT ck_vino_graduacion CHECK (graduacion BETWEEN 5 AND 20);
ALTER TABLE vino ADD CONSTRAINT ck_vino_volumen CHECK (volumen_ml IN (187, 375, 750, 1500, 3000));
ALTER TABLE vino ADD CONSTRAINT ck_vino_anada CHECK (anada BETWEEN 1990 AND 2100);

-- Cada cepa del corte tiene entre 1% y 100%.
-- (Que sumen 100 lo controla un trigger en 005)
ALTER TABLE composicion_vino ADD CONSTRAINT ck_composicion_porcentaje CHECK (porcentaje BETWEEN 1 AND 100);

-- Fincas, parcelas y lotes (RN-15)
ALTER TABLE finca ADD CONSTRAINT ck_finca_superficie CHECK (superficie_ha > 0);
ALTER TABLE parcela ADD CONSTRAINT ck_parcela_superficie CHECK (superficie_ha > 0);
ALTER TABLE parcela ADD CONSTRAINT ck_parcela_anio CHECK (anio_plantacion BETWEEN 1900 AND 2100);
ALTER TABLE lote_uva ADD CONSTRAINT ck_lote_kilos CHECK (kilos_cosechados > 0);

-- CHECK entre dos columnas: la cosecha tiene que ser del mismo año que la campaña
ALTER TABLE lote_uva ADD CONSTRAINT ck_lote_fecha_campania
    CHECK (EXTRACT(YEAR FROM fecha_cosecha) = campania);

-- Analisis de laboratorio
ALTER TABLE analisis_calidad ADD CONSTRAINT ck_analisis_brix CHECK (grado_brix BETWEEN 0 AND 40);
ALTER TABLE analisis_calidad ADD CONSTRAINT ck_analisis_ph CHECK (ph BETWEEN 2 AND 5);
ALTER TABLE analisis_calidad ADD CONSTRAINT ck_analisis_acidez CHECK (acidez_total > 0);

ALTER TABLE maridaje ADD CONSTRAINT ck_maridaje_temperatura CHECK (temperatura_servicio BETWEEN 2 AND 25);

ALTER TABLE empleado ADD CONSTRAINT ck_empleado_salario CHECK (salario > 0);

-- Clientes (RN-06)
ALTER TABLE cliente ADD CONSTRAINT ck_cliente_descuento CHECK (descuento BETWEEN 0 AND 50);
ALTER TABLE cliente ADD CONSTRAINT ck_cliente_tipo_doc CHECK (tipo_doc IN ('DNI', 'CUIT', 'PASAPORTE'));

-- CHECK entre varias columnas: cada tipo de cliente tiene solo sus datos.
--   socio:        no tiene zona, habilitacion ni pais
--   distribuidor: tiene zona y habilitacion, no tiene pais
--   exportador:   tiene pais, no tiene zona ni habilitacion
ALTER TABLE cliente ADD CONSTRAINT ck_cliente_datos_tipo CHECK (
    (tipo_cliente = 'socio'
        AND zona_cobertura IS NULL AND nro_habilitacion IS NULL AND pais_destino_principal IS NULL)
    OR (tipo_cliente = 'distribuidor'
        AND zona_cobertura IS NOT NULL AND nro_habilitacion IS NOT NULL AND pais_destino_principal IS NULL)
    OR (tipo_cliente = 'exportador'
        AND pais_destino_principal IS NOT NULL AND zona_cobertura IS NULL AND nro_habilitacion IS NULL)
);

-- CHECK entre dos columnas: el permiso vence despues de emitirse (RN-07)
ALTER TABLE permiso_exportacion ADD CONSTRAINT ck_permiso_fechas
    CHECK (fecha_vencimiento > fecha_emision);

-- CHECK entre columnas: total = subtotal - descuento (RN-08)
ALTER TABLE comprobante ADD CONSTRAINT ck_comprobante_total
    CHECK (total = subtotal - descuento);

-- Cantidades y precios mayores a 0 en los renglones (RN-15)
ALTER TABLE renglon_comprobante ADD CONSTRAINT ck_rc_cantidad CHECK (cantidad > 0);
ALTER TABLE renglon_comprobante ADD CONSTRAINT ck_rc_precio CHECK (precio_unitario > 0);
ALTER TABLE renglon_ingreso ADD CONSTRAINT ck_ri_cantidad CHECK (cantidad > 0);
ALTER TABLE renglon_transferencia ADD CONSTRAINT ck_rt_cantidad CHECK (cantidad > 0);

-- El stock nunca puede quedar negativo (RN-09)
ALTER TABLE stock_sala ADD CONSTRAINT ck_stock_sala_no_negativo CHECK (cantidad >= 0);
ALTER TABLE stock_deposito ADD CONSTRAINT ck_stock_deposito_no_negativo CHECK (cantidad >= 0);

-- El mail tiene que tener un @ y un punto despues
ALTER TABLE transportista ADD CONSTRAINT ck_transportista_email CHECK (email LIKE '%_@_%._%');


-- ---------- DEFAULT (valor que se pone si no se carga nada) ----------

-- Todo ingreso y transferencia empieza "en confeccion" y con la fecha y hora actual
ALTER TABLE ingreso ALTER COLUMN estado SET DEFAULT 'en_confeccion';
ALTER TABLE ingreso ALTER COLUMN fecha SET DEFAULT now();
ALTER TABLE transferencia ALTER COLUMN estado SET DEFAULT 'en_confeccion';
ALTER TABLE transferencia ALTER COLUMN fecha_confeccion SET DEFAULT now();

ALTER TABLE cliente ALTER COLUMN fecha_alta SET DEFAULT CURRENT_DATE;

-- El comprobante arranca en 0; los importes los calculan los triggers
ALTER TABLE comprobante ALTER COLUMN fecha SET DEFAULT now();
ALTER TABLE comprobante ALTER COLUMN subtotal SET DEFAULT 0;
ALTER TABLE comprobante ALTER COLUMN descuento SET DEFAULT 0;
ALTER TABLE comprobante ALTER COLUMN total SET DEFAULT 0;

ALTER TABLE stock_sala ALTER COLUMN cantidad SET DEFAULT 0;
ALTER TABLE stock_deposito ALTER COLUMN cantidad SET DEFAULT 0;

-- La auditoria guarda solo la fecha y el usuario que hizo el cambio
ALTER TABLE auditoria_precio ALTER COLUMN fecha_hora SET DEFAULT now();
ALTER TABLE auditoria_precio ALTER COLUMN usuario SET DEFAULT session_user;
