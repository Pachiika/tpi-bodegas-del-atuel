-- =============================================
-- 005_triggers.sql
-- Triggers: se ejecutan solos cuando se inserta, modifica o borra.
-- Cada uno tiene primero su funcion (RETURNS trigger) y despues el
-- CREATE TRIGGER que la conecta con la tabla.
--
-- Recordatorio:
--   NEW = la fila nueva (en INSERT y UPDATE)
--   OLD = la fila vieja (en UPDATE y DELETE)
--   BEFORE: corre antes de guardar, puede cambiar NEW o cancelar con un error
--   AFTER:  corre despues de guardar
-- =============================================
SET client_encoding = 'UTF8';   -- los archivos estan en UTF-8 (acentos bien tambien en Windows)


-- ---------------------------------------------
-- 1) Descuento del cliente segun su tipo (RN-06)
-- BEFORE INSERT/UPDATE en cliente
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_cliente_descuento()
RETURNS trigger
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- si no mandaron descuento, se pone el de su tipo
        IF NEW.descuento IS NULL THEN
            NEW.descuento := fn_descuento_por_tipo(NEW.tipo_cliente);
        END IF;
    ELSE
        -- si le cambian el tipo, se le pone el descuento del tipo nuevo
        IF NEW.tipo_cliente <> OLD.tipo_cliente THEN
            NEW.descuento := fn_descuento_por_tipo(NEW.tipo_cliente);
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_cliente_descuento
BEFORE INSERT OR UPDATE OF tipo_cliente ON cliente
FOR EACH ROW
EXECUTE FUNCTION fn_trg_cliente_descuento();


-- ---------------------------------------------
-- 2) Antes de vender: controlar stock y calcular el renglon (RN-08 y RN-09)
-- BEFORE INSERT en renglon_comprobante
-- El precio, el descuento y el subtotal no se cargan a mano: los pone
-- este trigger.
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_rc_validar_y_calcular()
RETURNS trigger
AS $$
DECLARE
    sala INTEGER;
    cliente_venta INTEGER;
    stock_actual INTEGER;
BEGIN
    -- de que sala y de que cliente es el comprobante
    SELECT id_sala, id_cliente INTO sala, cliente_venta
    FROM comprobante
    WHERE nro_comprobante = NEW.nro_comprobante;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El comprobante % no existe', NEW.nro_comprobante;
    END IF;

    -- stock del vino en esa sala.
    -- FOR UPDATE bloquea la fila: si dos personas compran la ultima botella
    -- al mismo tiempo, la segunda espera a que termine la primera.
    SELECT cantidad INTO stock_actual
    FROM stock_sala
    WHERE id_sala = sala AND cod_vino = NEW.cod_vino
    FOR UPDATE;

    IF stock_actual IS NULL THEN
        stock_actual := 0;
    END IF;

    IF stock_actual < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente del vino % en la sala %: hay %, se pidieron % (RN-09)',
            NEW.cod_vino, sala, stock_actual, NEW.cantidad;
    END IF;

    -- precio del vino
    SELECT precio INTO NEW.precio_unitario
    FROM vino
    WHERE cod_vino = NEW.cod_vino;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El vino % no existe', NEW.cod_vino USING ERRCODE = '23503';
    END IF;

    -- descuento del cliente y subtotal
    NEW.descuento_aplicado := fn_descuento_cliente(cliente_venta);
    NEW.subtotal := fn_subtotal_renglon(NEW.cantidad, NEW.precio_unitario, NEW.descuento_aplicado);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_rc_validar_y_calcular
BEFORE INSERT ON renglon_comprobante
FOR EACH ROW
EXECUTE FUNCTION fn_trg_rc_validar_y_calcular();


-- ---------------------------------------------
-- 3) Despues de vender: descontar el stock de la sala (RN-09)
-- AFTER INSERT en renglon_comprobante
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_rc_descontar_stock()
RETURNS trigger
AS $$
DECLARE
    sala INTEGER;
BEGIN
    SELECT id_sala INTO sala
    FROM comprobante
    WHERE nro_comprobante = NEW.nro_comprobante;

    UPDATE stock_sala
    SET cantidad = cantidad - NEW.cantidad
    WHERE id_sala = sala AND cod_vino = NEW.cod_vino;

    RETURN NULL;   -- en un AFTER el valor que se devuelve no importa
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_rc_descontar_stock
AFTER INSERT ON renglon_comprobante
FOR EACH ROW
EXECUTE FUNCTION fn_trg_rc_descontar_stock();


-- ---------------------------------------------
-- 4) Un renglon ya vendido no se puede cambiar (RN-08)
-- BEFORE UPDATE en renglon_comprobante
-- Solo se deja cambiar el descuento (lo usa la consulta U1) y el
-- subtotal se vuelve a calcular.
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_rc_proteger()
RETURNS trigger
AS $$
BEGIN
    IF NEW.nro_comprobante <> OLD.nro_comprobante
       OR NEW.cod_vino <> OLD.cod_vino
       OR NEW.cantidad <> OLD.cantidad
       OR NEW.precio_unitario <> OLD.precio_unitario THEN
        RAISE EXCEPTION 'No se puede modificar vino, cantidad ni precio de un renglón de venta ya registrado (RN-08)';
    END IF;

    NEW.subtotal := fn_subtotal_renglon(NEW.cantidad, NEW.precio_unitario, NEW.descuento_aplicado);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_rc_proteger
BEFORE UPDATE ON renglon_comprobante
FOR EACH ROW
EXECUTE FUNCTION fn_trg_rc_proteger();


-- ---------------------------------------------
-- 5) Recalcular el total de los comprobantes que cambiaron (RN-08)
-- AFTER ... FOR EACH STATEMENT (una vez por sentencia, no por fila)
-- "renglones_nuevos" y "renglones_viejos" son tablas que arma PostgreSQL
-- con todas las filas que toco la sentencia. Asi, si un UPDATE cambia
-- 1000 renglones del mismo comprobante, el total se recalcula una sola vez.
-- (El UPDATE "total = total" no cambia nada: solo hace que se dispare el
-- trigger 6, que es el que calcula los importes.)
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_rc_totales()
RETURNS trigger
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE comprobante SET total = total
        WHERE nro_comprobante IN (SELECT nro_comprobante FROM renglones_viejos);
    ELSE
        UPDATE comprobante SET total = total
        WHERE nro_comprobante IN (SELECT nro_comprobante FROM renglones_nuevos);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_rc_totales_ins
AFTER INSERT ON renglon_comprobante
REFERENCING NEW TABLE AS renglones_nuevos
FOR EACH STATEMENT
EXECUTE FUNCTION fn_trg_rc_totales();

CREATE TRIGGER trg_rc_totales_upd
AFTER UPDATE ON renglon_comprobante
REFERENCING NEW TABLE AS renglones_nuevos
FOR EACH STATEMENT
EXECUTE FUNCTION fn_trg_rc_totales();

CREATE TRIGGER trg_rc_totales_del
AFTER DELETE ON renglon_comprobante
REFERENCING OLD TABLE AS renglones_viejos
FOR EACH STATEMENT
EXECUTE FUNCTION fn_trg_rc_totales();


-- ---------------------------------------------
-- 6) Los importes del comprobante los calcula la base (RN-08)
-- BEFORE INSERT/UPDATE en comprobante
-- Aunque alguien mande otro total, se pisa con el calculado.
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_comprobante_importes()
RETURNS trigger
AS $$
BEGIN
    NEW.subtotal := fn_subtotal_bruto_comprobante(NEW.nro_comprobante);
    NEW.total := fn_total_comprobante(NEW.nro_comprobante);
    NEW.descuento := NEW.subtotal - NEW.total;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_comprobante_importes
BEFORE INSERT OR UPDATE ON comprobante
FOR EACH ROW
EXECUTE FUNCTION fn_trg_comprobante_importes();


-- ---------------------------------------------
-- 7) Estados del ingreso (RN-10)
-- BEFORE INSERT/UPDATE en ingreso
-- Solo se puede ir: en_confeccion -> terminado -> procesado
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_estado_ingreso()
RETURNS trigger
AS $$
DECLARE
    cant_renglones INTEGER;
BEGIN
    -- todo ingreso nuevo empieza en confeccion
    IF TG_OP = 'INSERT' THEN
        IF NEW.estado <> 'en_confeccion' THEN
            RAISE EXCEPTION 'Un ingreso nuevo debe crearse en estado en_confeccion (RN-10)';
        END IF;
        RETURN NEW;
    END IF;

    -- si el estado no cambia, no hay nada que controlar
    IF NEW.estado = OLD.estado THEN
        RETURN NEW;
    END IF;

    -- en_confeccion -> terminado: tiene que tener al menos un renglon
    IF OLD.estado = 'en_confeccion' AND NEW.estado = 'terminado' THEN
        SELECT COUNT(*) INTO cant_renglones
        FROM renglon_ingreso
        WHERE codigo_ingreso = NEW.codigo_ingreso;

        IF cant_renglones = 0 THEN
            RAISE EXCEPTION 'No se puede terminar el ingreso %: no tiene renglones (RN-10)', NEW.codigo_ingreso;
        END IF;
        RETURN NEW;
    END IF;

    -- terminado -> procesado: solo si lo hace el procedimiento sp_procesar_ingreso
    -- (el procedimiento pone la marca 'bodega.procesando' y corre como dueño de la tabla)
    IF OLD.estado = 'terminado' AND NEW.estado = 'procesado' THEN
        IF current_setting('bodega.procesando', true) IS DISTINCT FROM 'si'
           OR current_user <> (SELECT tableowner FROM pg_tables WHERE tablename = 'ingreso') THEN
            RAISE EXCEPTION 'El ingreso % solo puede pasar a procesado con el procedimiento sp_procesar_ingreso (RN-10)',
                NEW.codigo_ingreso;
        END IF;
        RETURN NEW;
    END IF;

    -- cualquier otro cambio (volver atras, saltear un estado) no se permite
    RAISE EXCEPTION 'Transición de estado inválida en el ingreso %: % -> % (RN-10)',
        NEW.codigo_ingreso, OLD.estado, NEW.estado;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ingreso_estado
BEFORE INSERT OR UPDATE OF estado ON ingreso
FOR EACH ROW
EXECUTE FUNCTION fn_trg_estado_ingreso();


-- ---------------------------------------------
-- 8) Estados de la transferencia (RN-11)
-- Igual que el anterior pero para transferencia.
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_estado_transferencia()
RETURNS trigger
AS $$
DECLARE
    cant_renglones INTEGER;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.estado <> 'en_confeccion' THEN
            RAISE EXCEPTION 'Una transferencia nueva debe crearse en estado en_confeccion (RN-11)';
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.estado = OLD.estado THEN
        RETURN NEW;
    END IF;

    IF OLD.estado = 'en_confeccion' AND NEW.estado = 'terminado' THEN
        SELECT COUNT(*) INTO cant_renglones
        FROM renglon_transferencia
        WHERE nro_transferencia = NEW.nro_transferencia;

        IF cant_renglones = 0 THEN
            RAISE EXCEPTION 'No se puede terminar la transferencia %: no tiene renglones (RN-11)', NEW.nro_transferencia;
        END IF;
        RETURN NEW;
    END IF;

    IF OLD.estado = 'terminado' AND NEW.estado = 'procesado' THEN
        IF current_setting('bodega.procesando', true) IS DISTINCT FROM 'si'
           OR current_user <> (SELECT tableowner FROM pg_tables WHERE tablename = 'transferencia') THEN
            RAISE EXCEPTION 'La transferencia % solo puede pasar a procesado con el procedimiento sp_procesar_transferencia (RN-11)',
                NEW.nro_transferencia;
        END IF;
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Transición de estado inválida en la transferencia %: % -> % (RN-11)',
        NEW.nro_transferencia, OLD.estado, NEW.estado;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_transferencia_estado
BEFORE INSERT OR UPDATE OF estado ON transferencia
FOR EACH ROW
EXECUTE FUNCTION fn_trg_estado_transferencia();


-- ---------------------------------------------
-- 9) La fecha de la transferencia es la actual y no se cambia (RN-11)
-- BEFORE INSERT/UPDATE en transferencia
-- (Esto no se puede hacer con un CHECK porque depende de la fecha de hoy)
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_transferencia_fecha()
RETURNS trigger
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.fecha_confeccion := now();
    ELSIF NEW.fecha_confeccion <> OLD.fecha_confeccion THEN
        RAISE EXCEPTION 'No se puede modificar la fecha de confección de la transferencia % (RN-11)',
            OLD.nro_transferencia;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_transferencia_fecha
BEFORE INSERT OR UPDATE ON transferencia
FOR EACH ROW
EXECUTE FUNCTION fn_trg_transferencia_fecha();


-- ---------------------------------------------
-- 10) Renglones de ingreso: solo se tocan si el ingreso esta en confeccion (RN-12)
-- BEFORE INSERT/UPDATE/DELETE en renglon_ingreso
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_bloqueo_renglon_ingreso()
RETURNS trigger
AS $$
DECLARE
    codigo INTEGER;
    estado_actual estado_ingreso;
BEGIN
    IF TG_OP = 'DELETE' THEN
        codigo := OLD.codigo_ingreso;
    ELSE
        codigo := NEW.codigo_ingreso;
    END IF;

    SELECT estado INTO estado_actual
    FROM ingreso
    WHERE codigo_ingreso = codigo;

    -- si el ingreso ya no existe es porque se esta borrando entero
    -- (ON DELETE CASCADE, consulta D5): ahi se deja borrar el renglon
    IF NOT FOUND THEN
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        END IF;
        RAISE EXCEPTION 'No existe el ingreso %', codigo USING ERRCODE = '23503';
    END IF;

    IF estado_actual <> 'en_confeccion' THEN
        RAISE EXCEPTION 'El ingreso % esta "%": no admite agregar, modificar ni quitar renglones (RN-12)',
            codigo, estado_actual;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_renglon_ingreso_bloqueo
BEFORE INSERT OR UPDATE OR DELETE ON renglon_ingreso
FOR EACH ROW
EXECUTE FUNCTION fn_trg_bloqueo_renglon_ingreso();


-- ---------------------------------------------
-- 11) Lo mismo para los renglones de transferencia (RN-12)
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_bloqueo_renglon_transferencia()
RETURNS trigger
AS $$
DECLARE
    numero INTEGER;
    estado_actual estado_transferencia;
BEGIN
    IF TG_OP = 'DELETE' THEN
        numero := OLD.nro_transferencia;
    ELSE
        numero := NEW.nro_transferencia;
    END IF;

    SELECT estado INTO estado_actual
    FROM transferencia
    WHERE nro_transferencia = numero;

    IF NOT FOUND THEN
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        END IF;
        RAISE EXCEPTION 'No existe la transferencia %', numero USING ERRCODE = '23503';
    END IF;

    IF estado_actual <> 'en_confeccion' THEN
        RAISE EXCEPTION 'La transferencia % esta "%": no admite agregar, modificar ni quitar renglones (RN-12)',
            numero, estado_actual;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_renglon_transf_bloqueo
BEFORE INSERT OR UPDATE OR DELETE ON renglon_transferencia
FOR EACH ROW
EXECUTE FUNCTION fn_trg_bloqueo_renglon_transferencia();


-- ---------------------------------------------
-- 12) Auditoria de cambios de precio (RN-13)
-- AFTER UPDATE OF precio en vino. Solo si el precio cambio (WHEN).
-- SECURITY DEFINER: la funcion escribe en la auditoria con los permisos
-- del dueño. Asi la API no necesita permiso para escribir en esa tabla
-- y no puede inventar registros falsos.
-- session_user = el usuario que se conecto a la base.
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_vino_auditoria_precio()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO auditoria_precio (cod_vino, precio_anterior, precio_nuevo, fecha_hora, usuario)
    VALUES (NEW.cod_vino, OLD.precio, NEW.precio, now(), session_user);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_vino_auditoria_precio
AFTER UPDATE OF precio ON vino
FOR EACH ROW
WHEN (OLD.precio <> NEW.precio)
EXECUTE FUNCTION fn_trg_vino_auditoria_precio();


-- ---------------------------------------------
-- 13) Solo los exportadores pueden tener permisos de exportacion (RN-07)
-- BEFORE INSERT/UPDATE en permiso_exportacion
-- (Como los clientes estan en una sola tabla, la clave foranea no alcanza:
-- hay que revisar el tipo del cliente.)
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_permiso_solo_exportador()
RETURNS trigger
AS $$
DECLARE
    tipo VARCHAR(20);
BEGIN
    SELECT tipo_cliente INTO tipo
    FROM cliente
    WHERE id_cliente = NEW.id_cliente;

    IF tipo IS DISTINCT FROM 'exportador' THEN
        RAISE EXCEPTION 'El cliente % no es exportador: no puede tener permisos de exportacion (RN-07)',
            NEW.id_cliente;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_permiso_solo_exportador
BEFORE INSERT OR UPDATE ON permiso_exportacion
FOR EACH ROW
EXECUTE FUNCTION fn_trg_permiso_solo_exportador();


-- ---------------------------------------------
-- 14) El corte de cepas tiene que sumar 100% (RN-05)
-- CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED:
-- no se controla en cada INSERT sino al final, cuando se hace COMMIT.
-- Hace falta porque las cepas se cargan de a una: despues de la primera
-- la suma da 85, despues de la segunda da 100. Recien al final tiene
-- que dar 100.
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_validar_composicion()
RETURNS trigger
AS $$
DECLARE
    vino_a_revisar INTEGER;
    suma NUMERIC;
BEGIN
    IF TG_OP = 'DELETE' THEN
        vino_a_revisar := OLD.cod_vino;
    ELSE
        vino_a_revisar := NEW.cod_vino;
    END IF;

    -- si el vino se borro, no hay nada que controlar
    IF NOT EXISTS (SELECT 1 FROM vino WHERE cod_vino = vino_a_revisar) THEN
        RETURN NULL;
    END IF;

    SELECT COALESCE(SUM(porcentaje), 0) INTO suma
    FROM composicion_vino
    WHERE cod_vino = vino_a_revisar;

    IF suma <> 100 THEN
        RAISE EXCEPTION 'Los porcentajes de corte del vino % suman % y deben sumar 100 (RN-05)',
            vino_a_revisar, suma;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- se controla cuando se agregan, cambian o quitan cepas
CREATE CONSTRAINT TRIGGER trg_composicion_suma_100
AFTER INSERT OR UPDATE OR DELETE ON composicion_vino
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validar_composicion();

-- y tambien cuando se crea un vino (asi no queda un vino sin cepas)
CREATE CONSTRAINT TRIGGER trg_vino_composicion_100
AFTER INSERT ON vino
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validar_composicion();
