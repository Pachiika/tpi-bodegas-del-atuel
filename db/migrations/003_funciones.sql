-- =====================================================================
-- 003_funciones.sql  ·  Bodegas del Atuel
-- Funciones reutilizables. Cada una indica propósito, parámetros y
-- volatilidad:
--   IMMUTABLE: mismo resultado para los mismos argumentos, siempre.
--   STABLE:    no modifica la base y devuelve lo mismo dentro de una
--              misma sentencia (puede leer tablas o la fecha actual).
-- =====================================================================

-- ---------------------------------------------------------------------
-- fn_descuento_por_tipo(tipo) -> NUMERIC         (RN-06)
-- Descuento por defecto según el tipo de cliente:
--   socio 10 %, distribuidor 20 %, exportador 30 %.
-- IMMUTABLE: depende solo del argumento.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_descuento_por_tipo(p_tipo tipo_cliente)
RETURNS NUMERIC
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE p_tipo
               WHEN 'socio'        THEN 10.00
               WHEN 'distribuidor' THEN 20.00
               WHEN 'exportador'   THEN 30.00
           END;
$$;

-- ---------------------------------------------------------------------
-- fn_descuento_cliente(id_cliente) -> NUMERIC     (RN-06)
-- Porcentaje de descuento vigente de un cliente (normalmente el de su
-- tipo; puede haberse ajustado, por ejemplo con la consulta U6).
-- Si el cliente no existe lanza una excepción.
-- STABLE: lee la tabla cliente.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_descuento_cliente(p_id_cliente INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_desc NUMERIC;
BEGIN
    SELECT descuento INTO v_desc FROM cliente WHERE id_cliente = p_id_cliente;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cliente % no existe', p_id_cliente
            USING ERRCODE = 'P0001';
    END IF;
    RETURN v_desc;
END;
$$;

-- ---------------------------------------------------------------------
-- fn_stock_sala(id_sala, cod_vino) -> INTEGER     (RN-09)
-- Stock disponible de un vino en una sala (0 si no hay fila).
-- STABLE: lee stock_sala.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_stock_sala(p_sala INTEGER, p_vino INTEGER)
RETURNS INTEGER
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(
        (SELECT cantidad FROM stock_sala
          WHERE id_sala = p_sala AND cod_vino = p_vino), 0);
$$;

-- ---------------------------------------------------------------------
-- fn_subtotal_renglon(cantidad, precio, descuento_pct) -> NUMERIC (RN-08)
-- Subtotal de un renglón con el descuento aplicado, redondeado a 2
-- decimales. IMMUTABLE: es un cálculo puro.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_subtotal_renglon(p_cantidad INTEGER,
                                               p_precio NUMERIC,
                                               p_descuento NUMERIC)
RETURNS NUMERIC
LANGUAGE sql IMMUTABLE AS $$
    SELECT ROUND(p_cantidad * p_precio * (1 - p_descuento / 100.0), 2);
$$;

-- ---------------------------------------------------------------------
-- fn_total_comprobante(nro) -> NUMERIC            (RN-08)
-- Total de un comprobante = suma de los subtotales de sus renglones
-- (cada uno ya tiene el descuento aplicado). 0 si no tiene renglones.
-- STABLE: lee renglon_comprobante.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_total_comprobante(p_nro INTEGER)
RETURNS NUMERIC
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(subtotal), 0)
      FROM renglon_comprobante
     WHERE nro_comprobante = p_nro;
$$;

-- ---------------------------------------------------------------------
-- fn_subtotal_bruto_comprobante(nro) -> NUMERIC   (RN-08)
-- Suma de cantidad * precio unitario, sin descuento.
-- STABLE: lee renglon_comprobante.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_subtotal_bruto_comprobante(p_nro INTEGER)
RETURNS NUMERIC
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(ROUND(cantidad * precio_unitario, 2)), 0)
      FROM renglon_comprobante
     WHERE nro_comprobante = p_nro;
$$;

-- ---------------------------------------------------------------------
-- fn_antiguedad_anios(fecha) -> INTEGER
-- Años completos transcurridos desde una fecha hasta hoy (se usa para la
-- antigüedad de empleados, clientes y comprobantes: U2, D1, D3, D4).
-- STABLE (no IMMUTABLE) porque depende de CURRENT_DATE.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_antiguedad_anios(p_fecha DATE)
RETURNS INTEGER
LANGUAGE sql STABLE AS $$
    SELECT EXTRACT(YEAR FROM age(CURRENT_DATE, p_fecha))::INTEGER;
$$;
