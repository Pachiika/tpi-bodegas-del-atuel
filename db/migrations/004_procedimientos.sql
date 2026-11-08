-- =============================================
-- 004_procedimientos.sql
-- Procedimientos para procesar ingresos y transferencias (RN-10 y RN-11).
-- Se ejecutan con CALL. Si algo falla en el medio, PostgreSQL deshace
-- todo lo que hizo el procedimiento (todo o nada).
--
-- SECURITY DEFINER: el procedimiento corre con los permisos del dueño de
-- las tablas. Asi la API (usuario app_rw) puede procesar un documento
-- llamando al procedimiento, pero NO puede cambiar el estado a mano con
-- un UPDATE (el trigger de estados de 005 no lo deja).
-- =============================================


-- Procesar un ingreso (RN-10)
-- Suma al deposito las botellas de un ingreso terminado y lo pasa a procesado.
-- Uso: CALL sp_procesar_ingreso(15);
CREATE OR REPLACE PROCEDURE sp_procesar_ingreso(codigo INTEGER)
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    estado_actual estado_documento;
    cant_renglones INTEGER;
    r RECORD;
BEGIN
    -- 1) Buscar el ingreso. FOR UPDATE lo bloquea para que nadie
    --    lo procese al mismo tiempo.
    SELECT estado INTO estado_actual
    FROM ingreso
    WHERE codigo_ingreso = codigo
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El ingreso % no existe (RN-10)', codigo;
    END IF;

    IF estado_actual <> 'terminado' THEN
        RAISE EXCEPTION 'El ingreso % esta "%": solo un ingreso terminado se puede procesar (RN-10)',
            codigo, estado_actual;
    END IF;

    SELECT COUNT(*) INTO cant_renglones
    FROM renglon_ingreso
    WHERE codigo_ingreso = codigo;

    IF cant_renglones = 0 THEN
        RAISE EXCEPTION 'El ingreso % no tiene renglones (RN-10)', codigo;
    END IF;

    -- 2) Recorrer los renglones y sumar cada vino al deposito
    FOR r IN SELECT cod_vino, cantidad
             FROM renglon_ingreso
             WHERE codigo_ingreso = codigo
             ORDER BY cod_vino
    LOOP
        IF EXISTS (SELECT 1 FROM stock_deposito WHERE cod_vino = r.cod_vino) THEN
            UPDATE stock_deposito
            SET cantidad = cantidad + r.cantidad
            WHERE cod_vino = r.cod_vino;
        ELSE
            -- el vino todavia no tenia stock en el deposito
            INSERT INTO stock_deposito (cod_vino, cantidad)
            VALUES (r.cod_vino, r.cantidad);
        END IF;
    END LOOP;

    -- 3) Pasar a procesado. La "marca" bodega.procesando le avisa al
    --    trigger de estados que el cambio viene de este procedimiento.
    PERFORM set_config('bodega.procesando', 'si', true);
    UPDATE ingreso SET estado = 'procesado' WHERE codigo_ingreso = codigo;
    PERFORM set_config('bodega.procesando', 'no', true);
END;
$$ LANGUAGE plpgsql;


-- Procesar una transferencia (RN-11)
-- Resta del deposito y suma a la sala las botellas de una transferencia
-- terminada, y la pasa a procesado. Si en el deposito no alcanza para algun
-- vino, no se cambia nada.
-- Uso: CALL sp_procesar_transferencia(1234);
CREATE OR REPLACE PROCEDURE sp_procesar_transferencia(numero INTEGER)
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    estado_actual estado_documento;
    sala INTEGER;
    cant_renglones INTEGER;
    disponible INTEGER;
    r RECORD;
BEGIN
    -- 1) Buscar la transferencia y bloquearla
    SELECT estado, id_sala INTO estado_actual, sala
    FROM transferencia
    WHERE nro_transferencia = numero
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La transferencia % no existe (RN-11)', numero;
    END IF;

    IF estado_actual <> 'terminado' THEN
        RAISE EXCEPTION 'La transferencia % esta "%": solo una transferencia terminada se puede procesar (RN-11)',
            numero, estado_actual;
    END IF;

    SELECT COUNT(*) INTO cant_renglones
    FROM renglon_transferencia
    WHERE nro_transferencia = numero;

    IF cant_renglones = 0 THEN
        RAISE EXCEPTION 'La transferencia % no tiene renglones (RN-11)', numero;
    END IF;

    -- 2) Primero revisar que haya stock en el deposito para TODOS los vinos.
    --    FOR UPDATE bloquea la fila de stock hasta que termine el procedimiento.
    FOR r IN SELECT cod_vino, cantidad
             FROM renglon_transferencia
             WHERE nro_transferencia = numero
             ORDER BY cod_vino
    LOOP
        SELECT cantidad INTO disponible
        FROM stock_deposito
        WHERE cod_vino = r.cod_vino
        FOR UPDATE;

        IF disponible IS NULL OR disponible < r.cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente en el depósito para el vino % (pedido %, hay %). La transferencia % no se proceso (RN-11)',
                r.cod_vino, r.cantidad, COALESCE(disponible, 0), numero;
        END IF;
    END LOOP;

    -- 3) Ahora si: restar del deposito y sumar a la sala
    FOR r IN SELECT cod_vino, cantidad
             FROM renglon_transferencia
             WHERE nro_transferencia = numero
    LOOP
        UPDATE stock_deposito
        SET cantidad = cantidad - r.cantidad
        WHERE cod_vino = r.cod_vino;

        IF EXISTS (SELECT 1 FROM stock_sala WHERE id_sala = sala AND cod_vino = r.cod_vino) THEN
            UPDATE stock_sala
            SET cantidad = cantidad + r.cantidad
            WHERE id_sala = sala AND cod_vino = r.cod_vino;
        ELSE
            INSERT INTO stock_sala (id_sala, cod_vino, cantidad)
            VALUES (sala, r.cod_vino, r.cantidad);
        END IF;
    END LOOP;

    -- 4) Pasar a procesado (con la misma marca que en el ingreso)
    PERFORM set_config('bodega.procesando', 'si', true);
    UPDATE transferencia SET estado = 'procesado' WHERE nro_transferencia = numero;
    PERFORM set_config('bodega.procesando', 'no', true);
END;
$$ LANGUAGE plpgsql;
