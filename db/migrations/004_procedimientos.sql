-- 004_procedimientos.sql: Lógica transaccional de procesamiento con control de privilegios mediante SECURITY DEFINER.
SET client_encoding = 'UTF8';   -- los archivos estan en UTF-8 (acentos bien tambien en Windows)


-- Procesar un ingreso (RN-10)
-- Suma al deposito las botellas de un ingreso terminado y lo pasa a procesado.

CREATE OR REPLACE PROCEDURE sp_procesar_ingreso(codigo INTEGER)
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    estado_actual estado_ingreso;
    cant_renglones INTEGER;
    r RECORD;
BEGIN
    -- 1) Buscar el ingreso. FOR UPDATE lo bloquea para que nadie lo procese al mismo tiempo.
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

    -- 3) Pasar a procesado. La "marca" bodega.procesando le avisa al trigger de estados que el cambio viene de este procedimiento.
    PERFORM set_config('bodega.procesando', 'si', true);
    UPDATE ingreso SET estado = 'procesado' WHERE codigo_ingreso = codigo;
    PERFORM set_config('bodega.procesando', 'no', true);
END;
$$ LANGUAGE plpgsql;


-- RN-11: Procesa transferencia de stock garantizando disponibilidad atómica entre depósito y sala.
CREATE OR REPLACE PROCEDURE sp_procesar_transferencia(numero INTEGER)
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    estado_actual estado_transferencia;
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

    -- 2) Verifica stock total disponible aplicando bloqueo exclusivo (FOR UPDATE).
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
