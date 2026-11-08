-- =====================================================================
-- 005_triggers.sql  ·  Bodegas del Atuel
-- Triggers que protegen las reglas de negocio. Cada bloque indica la
-- regla (RN-xx) que garantiza.
--
-- Resumen:
--   T1  trg_cliente_descuento          BEFORE INSERT/UPDATE cliente        RN-06
--   T2  trg_rc_validar_y_calcular      BEFORE INSERT renglon_comprobante   RN-08, RN-09
--   T3  trg_rc_descontar_stock         AFTER  INSERT renglon_comprobante   RN-09
--   T4  trg_rc_proteger                BEFORE UPDATE renglon_comprobante   RN-08
--   T5  trg_rc_totales_ins/upd/del     AFTER  (sentencia) renglones        RN-08
--   T6  trg_comprobante_importes       BEFORE INSERT/UPDATE comprobante    RN-08
--   T7  trg_ingreso_estado             BEFORE INSERT/UPDATE ingreso        RN-10
--   T8  trg_transferencia_estado       BEFORE INSERT/UPDATE transferencia  RN-11
--   T9  trg_transferencia_fecha        BEFORE INSERT/UPDATE transferencia  RN-11
--   T10 trg_renglon_ingreso_bloqueo    BEFORE I/U/D renglon_ingreso        RN-12
--   T11 trg_renglon_transf_bloqueo     BEFORE I/U/D renglon_transferencia  RN-12
--   T12 trg_vino_auditoria_precio      AFTER  UPDATE OF precio ON vino     RN-13
--   T13 trg_composicion_suma_100       CONSTRAINT TRIGGER diferido         RN-05
--   T14 trg_vino_composicion_100       CONSTRAINT TRIGGER diferido         RN-05
--
-- Los mensajes de error terminan con el código de la regla para que la
-- API y el front los muestren tal cual (SQLSTATE P0001 -> HTTP 409).
-- =====================================================================


-- =====================================================================
-- T1 · RN-06: el descuento depende del tipo de cliente
-- Al dar de alta un cliente sin descuento explícito se asigna el de su
-- tipo. Si se cambia el tipo de cliente, se vuelve al descuento del
-- nuevo tipo.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_trg_cliente_descuento() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.descuento IS NULL THEN
            NEW.descuento := fn_descuento_por_tipo(NEW.tipo_cliente);
        END IF;
    ELSIF NEW.tipo_cliente IS DISTINCT FROM OLD.tipo_cliente THEN
        NEW.descuento := fn_descuento_por_tipo(NEW.tipo_cliente);
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_cliente_descuento
BEFORE INSERT OR UPDATE OF tipo_cliente ON cliente
FOR EACH ROW EXECUTE FUNCTION fn_trg_cliente_descuento();


-- =====================================================================
-- T2 · RN-09 y RN-08: validar stock y calcular el renglón de venta
-- * Bloquea la fila de stock de la sala (FOR UPDATE): si dos ventas
--   compiten por la última botella, la segunda espera y luego ve el
--   stock ya descontado.
-- * Rechaza la venta si no hay stock suficiente.
-- * El precio unitario, el descuento y el subtotal NO se cargan a mano:
--   se toman del vino y del cliente y se calculan con las funciones.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_trg_rc_validar_y_calcular() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_sala      INTEGER;
    v_cliente   INTEGER;
    v_stock     INTEGER;
BEGIN
    SELECT id_sala, id_cliente INTO v_sala, v_cliente
      FROM comprobante
     WHERE nro_comprobante = NEW.nro_comprobante;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El comprobante % no existe', NEW.nro_comprobante;
    END IF;

    SELECT cantidad INTO v_stock
      FROM stock_sala
     WHERE id_sala = v_sala AND cod_vino = NEW.cod_vino
       FOR UPDATE;

    IF COALESCE(v_stock, 0) < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente del vino % en la sala %: hay %, se pidieron % (RN-09)',
                        NEW.cod_vino, v_sala, COALESCE(v_stock, 0), NEW.cantidad;
    END IF;

    SELECT precio INTO NEW.precio_unitario FROM vino WHERE cod_vino = NEW.cod_vino;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El vino % no existe', NEW.cod_vino USING ERRCODE = '23503';
    END IF;

    NEW.descuento_aplicado := fn_descuento_cliente(v_cliente);
    NEW.subtotal := fn_subtotal_renglon(NEW.cantidad, NEW.precio_unitario, NEW.descuento_aplicado);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_rc_validar_y_calcular
BEFORE INSERT ON renglon_comprobante
FOR EACH ROW EXECUTE FUNCTION fn_trg_rc_validar_y_calcular();


-- =====================================================================
-- T3 · RN-09: descontar el stock de la sala después de vender
-- El CHECK (cantidad >= 0) de stock_sala es la segunda barrera.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_trg_rc_descontar_stock() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE stock_sala s
       SET cantidad = s.cantidad - NEW.cantidad
      FROM comprobante c
     WHERE c.nro_comprobante = NEW.nro_comprobante
       AND s.id_sala = c.id_sala
       AND s.cod_vino = NEW.cod_vino;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_rc_descontar_stock
AFTER INSERT ON renglon_comprobante
FOR EACH ROW EXECUTE FUNCTION fn_trg_rc_descontar_stock();


-- =====================================================================
-- T4 · RN-08: un renglón de venta no cambia de vino, cantidad ni precio
-- Solo se permite recalcular el descuento (por ejemplo, consulta U1);
-- el subtotal se recalcula siempre con la función.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_trg_rc_proteger() RETURNS trigger
LANGUAGE plpgsql AS $$
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
$$;

CREATE TRIGGER trg_rc_proteger
BEFORE UPDATE ON renglon_comprobante
FOR EACH ROW EXECUTE FUNCTION fn_trg_rc_proteger();


-- =====================================================================
-- T5 · RN-08: recalcular los importes de los comprobantes afectados
-- Triggers por SENTENCIA con tablas de transición: si una sentencia toca
-- miles de renglones (por ejemplo U1), cada comprobante se recalcula una
-- sola vez y no una vez por renglón.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_trg_rc_totales() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE comprobante c SET total = c.total
         WHERE c.nro_comprobante IN (SELECT DISTINCT nro_comprobante FROM renglones_viejos);
    ELSE
        UPDATE comprobante c SET total = c.total
         WHERE c.nro_comprobante IN (SELECT DISTINCT nro_comprobante FROM renglones_nuevos);
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_rc_totales_ins
AFTER INSERT ON renglon_comprobante
REFERENCING NEW TABLE AS renglones_nuevos
FOR EACH STATEMENT EXECUTE FUNCTION fn_trg_rc_totales();

CREATE TRIGGER trg_rc_totales_upd
AFTER UPDATE ON renglon_comprobante
REFERENCING NEW TABLE AS renglones_nuevos
FOR EACH STATEMENT EXECUTE FUNCTION fn_trg_rc_totales();

CREATE TRIGGER trg_rc_totales_del
AFTER DELETE ON renglon_comprobante
REFERENCING OLD TABLE AS renglones_viejos
FOR EACH STATEMENT EXECUTE FUNCTION fn_trg_rc_totales();


-- =====================================================================
-- T6 · RN-08: los importes del comprobante los calcula la base
-- En cada INSERT/UPDATE se ignora lo que venga en subtotal, descuento y
-- total y se recalcula a partir de los renglones. Así el total nunca se
-- carga a mano.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_trg_comprobante_importes() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.subtotal  := fn_subtotal_bruto_comprobante(NEW.nro_comprobante);
    NEW.total     := fn_total_comprobante(NEW.nro_comprobante);
    NEW.descuento := NEW.subtotal - NEW.total;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_comprobante_importes
BEFORE INSERT OR UPDATE ON comprobante
FOR EACH ROW EXECUTE FUNCTION fn_trg_comprobante_importes();


-- =====================================================================
-- T7 y T8 · RN-10 / RN-11: control de estados de ingresos y transferencias
-- * Un documento nuevo siempre nace en 'en_confeccion'.
-- * Transiciones válidas: en_confeccion -> terminado -> procesado.
-- * No se retrocede ni se salta de estado.
-- * Para terminar, el documento debe tener al menos un renglón.
-- * Solo el procedimiento correspondiente puede pasar a 'procesado'
--   (marca bodega.procesando y usuario propietario; ver 004).
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_trg_control_estado() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_regla     TEXT := CASE TG_TABLE_NAME WHEN 'ingreso' THEN 'RN-10' ELSE 'RN-11' END;
    v_doc       TEXT := CASE TG_TABLE_NAME WHEN 'ingreso' THEN 'el ingreso' ELSE 'la transferencia' END;
    v_nuevo     TEXT := CASE TG_TABLE_NAME WHEN 'ingreso' THEN 'Un ingreso nuevo' ELSE 'Una transferencia nueva' END;
    v_proc      TEXT := CASE TG_TABLE_NAME WHEN 'ingreso' THEN 'sp_procesar_ingreso' ELSE 'sp_procesar_transferencia' END;
    v_id        INTEGER;
    v_renglones INTEGER;
    v_owner     NAME;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.estado <> 'en_confeccion' THEN
            RAISE EXCEPTION '% debe crearse en estado en_confeccion (%)', v_nuevo, v_regla;
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.estado = OLD.estado THEN
        RETURN NEW;
    END IF;

    IF TG_TABLE_NAME = 'ingreso' THEN
        v_id := NEW.codigo_ingreso;
    ELSE
        v_id := NEW.nro_transferencia;
    END IF;

    IF OLD.estado = 'en_confeccion' AND NEW.estado = 'terminado' THEN
        IF TG_TABLE_NAME = 'ingreso' THEN
            SELECT count(*) INTO v_renglones FROM renglon_ingreso WHERE codigo_ingreso = v_id;
        ELSE
            SELECT count(*) INTO v_renglones FROM renglon_transferencia WHERE nro_transferencia = v_id;
        END IF;
        IF v_renglones = 0 THEN
            RAISE EXCEPTION 'No se puede terminar % %: no tiene renglones (%)', v_doc, v_id, v_regla;
        END IF;
        RETURN NEW;
    END IF;

    IF OLD.estado = 'terminado' AND NEW.estado = 'procesado' THEN
        SELECT pg_get_userbyid(relowner) INTO v_owner FROM pg_class WHERE oid = TG_RELID;
        IF current_setting('bodega.procesando', true) IS DISTINCT FROM 'si'
           OR current_user <> v_owner THEN
            RAISE EXCEPTION '% % solo puede pasar a procesado mediante el procedimiento % (%)',
                            initcap(split_part(v_doc, ' ', 1)) || ' ' || split_part(v_doc, ' ', 2), v_id, v_proc, v_regla;
        END IF;
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Transición de estado inválida en % %: % -> %. Solo se permite en_confeccion -> terminado -> procesado (%)',
                    v_doc, v_id, OLD.estado, NEW.estado, v_regla;
END;
$$;

CREATE TRIGGER trg_ingreso_estado
BEFORE INSERT OR UPDATE OF estado ON ingreso
FOR EACH ROW EXECUTE FUNCTION fn_trg_control_estado();

CREATE TRIGGER trg_transferencia_estado
BEFORE INSERT OR UPDATE OF estado ON transferencia
FOR EACH ROW EXECUTE FUNCTION fn_trg_control_estado();


-- =====================================================================
-- T9 · RN-11: la fecha de confección de una transferencia es la actual
-- y no se puede modificar.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_trg_transferencia_fecha() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.fecha_confeccion := CURRENT_DATE;
    ELSIF NEW.fecha_confeccion IS DISTINCT FROM OLD.fecha_confeccion THEN
        RAISE EXCEPTION 'La fecha de confección de la transferencia % no se puede modificar (RN-11)',
                        OLD.nro_transferencia;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_transferencia_fecha
BEFORE INSERT OR UPDATE ON transferencia
FOR EACH ROW EXECUTE FUNCTION fn_trg_transferencia_fecha();


-- =====================================================================
-- T10 y T11 · RN-12: un ingreso o transferencia que no está en
-- confección no admite agregar, modificar ni quitar renglones.
-- Excepción: si la cabecera ya no existe (se está borrando con
-- ON DELETE CASCADE, por ejemplo la consulta D5), se permite.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_trg_bloqueo_renglones() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_id     INTEGER;
    v_estado estado_documento;
    v_doc    TEXT;
BEGIN
    IF TG_TABLE_NAME = 'renglon_ingreso' THEN
        v_doc := 'el ingreso';
        IF TG_OP = 'DELETE' THEN v_id := OLD.codigo_ingreso; ELSE v_id := NEW.codigo_ingreso; END IF;
        SELECT estado INTO v_estado FROM ingreso WHERE codigo_ingreso = v_id;
    ELSE
        v_doc := 'la transferencia';
        IF TG_OP = 'DELETE' THEN v_id := OLD.nro_transferencia; ELSE v_id := NEW.nro_transferencia; END IF;
        SELECT estado INTO v_estado FROM transferencia WHERE nro_transferencia = v_id;
    END IF;

    IF NOT FOUND THEN
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;          -- borrado en cascada de la cabecera
        END IF;
        RAISE EXCEPTION 'No existe % %', v_doc, v_id USING ERRCODE = '23503';
    END IF;

    IF v_estado <> 'en_confeccion' THEN
        RAISE EXCEPTION '% % está en estado "%": no admite agregar, modificar ni quitar renglones (RN-12)',
                        initcap(split_part(v_doc, ' ', 1)) || ' ' || split_part(v_doc, ' ', 2), v_id, v_estado;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_renglon_ingreso_bloqueo
BEFORE INSERT OR UPDATE OR DELETE ON renglon_ingreso
FOR EACH ROW EXECUTE FUNCTION fn_trg_bloqueo_renglones();

CREATE TRIGGER trg_renglon_transf_bloqueo
BEFORE INSERT OR UPDATE OR DELETE ON renglon_transferencia
FOR EACH ROW EXECUTE FUNCTION fn_trg_bloqueo_renglones();


-- =====================================================================
-- T12 · RN-13: todo cambio de precio de un vino queda auditado
-- SECURITY DEFINER: la auditoría la escribe el propietario, así el rol
-- de la API no necesita (ni tiene) permiso de INSERT sobre la tabla de
-- auditoría y no puede falsificarla. Se registra session_user, que es el
-- usuario real que se conectó.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_trg_vino_auditoria_precio() RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO auditoria_precio (cod_vino, precio_anterior, precio_nuevo, fecha_hora, usuario)
    VALUES (NEW.cod_vino, OLD.precio, NEW.precio, now(), session_user);
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_vino_auditoria_precio
AFTER UPDATE OF precio ON vino
FOR EACH ROW
WHEN (OLD.precio IS DISTINCT FROM NEW.precio)
EXECUTE FUNCTION fn_trg_vino_auditoria_precio();


-- =====================================================================
-- T13 y T14 · RN-05: los porcentajes de corte de un vino suman 100
-- CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED: se evalúa al hacer
-- COMMIT, así se pueden insertar el vino y sus cepas en varias
-- sentencias dentro de la misma transacción. Un vino sin composición
-- tampoco es válido (T14).
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_trg_validar_composicion() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_vino  INTEGER;
    v_suma  NUMERIC;
BEGIN
    IF TG_OP = 'DELETE' THEN v_vino := OLD.cod_vino; ELSE v_vino := NEW.cod_vino; END IF;

    -- Si el vino fue borrado (cascada), no hay nada que validar.
    IF NOT EXISTS (SELECT 1 FROM vino WHERE cod_vino = v_vino) THEN
        RETURN NULL;
    END IF;

    SELECT COALESCE(SUM(porcentaje), 0) INTO v_suma
      FROM composicion_vino WHERE cod_vino = v_vino;

    IF v_suma <> 100 THEN
        RAISE EXCEPTION 'Los porcentajes de corte del vino % suman % y deben sumar 100 (RN-05)',
                        v_vino, v_suma;
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_composicion_suma_100
AFTER INSERT OR UPDATE OR DELETE ON composicion_vino
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION fn_trg_validar_composicion();

CREATE CONSTRAINT TRIGGER trg_vino_composicion_100
AFTER INSERT ON vino
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION fn_trg_validar_composicion();
