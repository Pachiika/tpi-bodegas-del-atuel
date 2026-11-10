-- 003_funciones.sql: Definición de funciones auxiliares para triggers, vistas y la aplicación.
SET client_encoding = 'UTF8';   -- los archivos estan en UTF-8 (acentos bien tambien en Windows)


-- RN-06: Cálculo del descuento porcentual según el rol del cliente.
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


-- RN-06: Obtiene el porcentaje de descuento registrado de un cliente (falla si no existe).
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


-- Calcula la antigüedad en años desde una fecha hasta la fecha actual.
CREATE OR REPLACE FUNCTION fn_antiguedad_anios(fecha DATE)
RETURNS INTEGER
AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM age(CURRENT_DATE, fecha));
END;
$$ LANGUAGE plpgsql;
