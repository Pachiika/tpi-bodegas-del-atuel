-- =============================================
-- 003_funciones.sql
-- Funciones que despues usan los triggers, las consultas y la API.
-- =============================================


-- Descuento segun el tipo de cliente (RN-06)
-- socio = 10%, distribuidor = 20%, exportador = 30%
-- Ejemplo: SELECT fn_descuento_por_tipo('socio');  --> 10
CREATE OR REPLACE FUNCTION fn_descuento_por_tipo(tipo VARCHAR)
RETURNS NUMERIC
AS $$
BEGIN
    IF tipo = 'socio' THEN
        RETURN 10;
    ELSIF tipo = 'distribuidor' THEN
        RETURN 20;
    ELSE
        RETURN 30;   -- exportador
    END IF;
END;
$$ LANGUAGE plpgsql;


-- Descuento que tiene guardado un cliente (RN-06)
-- Si el cliente no existe, da error.
-- (el parametro no se llama "cliente" porque se confundiria con la tabla)
-- Ejemplo: SELECT fn_descuento_cliente(1);
CREATE OR REPLACE FUNCTION fn_descuento_cliente(id_buscado INTEGER)
RETURNS NUMERIC
AS $$
DECLARE
    desc_cliente NUMERIC;
BEGIN
    SELECT descuento INTO desc_cliente
    FROM cliente
    WHERE id_cliente = id_buscado;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cliente % no existe', id_buscado;
    END IF;

    RETURN desc_cliente;
END;
$$ LANGUAGE plpgsql;


-- Cuantas botellas hay de un vino en una sala (RN-09)
-- Si no hay ninguna fila de stock, devuelve 0.
-- Ejemplo: SELECT fn_stock_sala(1, 5);
CREATE OR REPLACE FUNCTION fn_stock_sala(sala INTEGER, vino INTEGER)
RETURNS INTEGER
AS $$
DECLARE
    stock_actual INTEGER;
BEGIN
    SELECT cantidad INTO stock_actual
    FROM stock_sala
    WHERE id_sala = sala AND cod_vino = vino;

    IF stock_actual IS NULL THEN
        RETURN 0;
    END IF;

    RETURN stock_actual;
END;
$$ LANGUAGE plpgsql;


-- Subtotal de un renglon: cantidad * precio, menos el descuento (RN-08)
-- Se redondea a 2 decimales.
-- Ejemplo: SELECT fn_subtotal_renglon(2, 10000, 20);  --> 16000.00
CREATE OR REPLACE FUNCTION fn_subtotal_renglon(cantidad INTEGER, precio NUMERIC, descuento NUMERIC)
RETURNS NUMERIC
AS $$
BEGIN
    RETURN ROUND(cantidad * precio * (1 - descuento / 100.0), 2);
END;
$$ LANGUAGE plpgsql;


-- Total de un comprobante: suma de los subtotales de sus renglones (RN-08)
-- Si no tiene renglones devuelve 0.
CREATE OR REPLACE FUNCTION fn_total_comprobante(numero INTEGER)
RETURNS NUMERIC
AS $$
DECLARE
    total NUMERIC;
BEGIN
    SELECT SUM(subtotal) INTO total
    FROM renglon_comprobante
    WHERE nro_comprobante = numero;

    RETURN COALESCE(total, 0);
END;
$$ LANGUAGE plpgsql;


-- Subtotal SIN descuento de un comprobante: suma de cantidad * precio (RN-08)
CREATE OR REPLACE FUNCTION fn_subtotal_bruto_comprobante(numero INTEGER)
RETURNS NUMERIC
AS $$
DECLARE
    bruto NUMERIC;
BEGIN
    SELECT SUM(ROUND(cantidad * precio_unitario, 2)) INTO bruto
    FROM renglon_comprobante
    WHERE nro_comprobante = numero;

    RETURN COALESCE(bruto, 0);
END;
$$ LANGUAGE plpgsql;


-- Cuantos años pasaron desde una fecha hasta hoy
-- Se usa para la antiguedad de empleados y clientes (consultas U2, D1, D3, D4).
-- Ejemplo: SELECT fn_antiguedad_anios('2020-03-15');
CREATE OR REPLACE FUNCTION fn_antiguedad_anios(fecha DATE)
RETURNS INTEGER
AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM age(CURRENT_DATE, fecha));
END;
$$ LANGUAGE plpgsql;
