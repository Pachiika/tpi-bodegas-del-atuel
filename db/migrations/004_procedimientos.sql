-- =====================================================================
-- 004_procedimientos.sql  ·  Bodegas del Atuel
-- Procedimientos transaccionales (RN-10 y RN-11).
--
-- Cómo garantizan "todo o nada":
--   * Un CALL corre dentro de una transacción (la del cliente o una
--     implícita). Si cualquier paso lanza una excepción, PostgreSQL
--     revierte TODO lo que hizo el procedimiento.
--   * Bloquean con FOR UPDATE la cabecera y las filas de stock que van a
--     tocar, siempre en el mismo orden (por cod_vino) para evitar
--     deadlocks entre dos procesos simultáneos.
--
-- Seguridad:
--   * SECURITY DEFINER: corren con los privilegios del propietario.
--   * Antes de pasar el documento a 'procesado' marcan la transacción con
--     la variable bodega.procesando = 'si'. El trigger de estados (005)
--     solo acepta terminado -> procesado si esa marca existe Y el usuario
--     efectivo es el propietario de la tabla, es decir, si viene de este
--     procedimiento. Así nadie puede "procesar" un documento con un UPDATE
--     directo sin mover el stock.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_procesar_ingreso(codigo_ingreso)                         RN-10
-- Suma al depósito central las botellas de un ingreso TERMINADO y lo
-- pasa a PROCESADO.
-- Uso: CALL sp_procesar_ingreso(15);
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_procesar_ingreso(p_codigo INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_estado    estado_documento;
    v_renglones INTEGER;
BEGIN
    -- 1. Bloquear la cabecera para que nadie la procese en paralelo.
    SELECT estado INTO v_estado
      FROM ingreso
     WHERE codigo_ingreso = p_codigo
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El ingreso % no existe (RN-10)', p_codigo;
    END IF;
    IF v_estado <> 'terminado' THEN
        RAISE EXCEPTION 'El ingreso % está en estado "%": solo un ingreso terminado puede procesarse (RN-10)',
                        p_codigo, v_estado;
    END IF;

    SELECT count(*) INTO v_renglones FROM renglon_ingreso WHERE codigo_ingreso = p_codigo;
    IF v_renglones = 0 THEN
        RAISE EXCEPTION 'El ingreso % no tiene renglones (RN-10)', p_codigo;
    END IF;

    -- 2. Bloquear las filas de stock existentes, en orden fijo.
    PERFORM 1
       FROM stock_deposito d
       JOIN renglon_ingreso r ON r.cod_vino = d.cod_vino
      WHERE r.codigo_ingreso = p_codigo
      ORDER BY d.cod_vino
        FOR UPDATE OF d;

    -- 3. Sumar al depósito (crea la fila si el vino todavía no tenía stock).
    INSERT INTO stock_deposito (cod_vino, cantidad)
    SELECT cod_vino, cantidad
      FROM renglon_ingreso
     WHERE codigo_ingreso = p_codigo
    ON CONFLICT (cod_vino)
    DO UPDATE SET cantidad = stock_deposito.cantidad + EXCLUDED.cantidad;

    -- 4. Cambiar el estado (el trigger valida la transición).
    PERFORM set_config('bodega.procesando', 'si', true);
    UPDATE ingreso SET estado = 'procesado' WHERE codigo_ingreso = p_codigo;
    PERFORM set_config('bodega.procesando', 'no', true);
END;
$$;

COMMENT ON PROCEDURE sp_procesar_ingreso(INTEGER) IS
    'RN-10: impacta un ingreso terminado en el depósito central y lo pasa a procesado (todo o nada).';

-- ---------------------------------------------------------------------
-- sp_procesar_transferencia(nro_transferencia)                RN-11
-- Descuenta del depósito central y suma al stock de la sala las botellas
-- de una transferencia TERMINADA, y la pasa a PROCESADA.
-- Si el depósito no alcanza para algún renglón, no se modifica nada.
-- Uso: CALL sp_procesar_transferencia(1234);
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_procesar_transferencia(p_nro INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_estado    estado_documento;
    v_sala      INTEGER;
    v_renglones INTEGER;
    v_faltante  RECORD;
BEGIN
    -- 1. Bloquear la cabecera.
    SELECT estado, id_sala INTO v_estado, v_sala
      FROM transferencia
     WHERE nro_transferencia = p_nro
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La transferencia % no existe (RN-11)', p_nro;
    END IF;
    IF v_estado <> 'terminado' THEN
        RAISE EXCEPTION 'La transferencia % está en estado "%": solo una transferencia terminada puede procesarse (RN-11)',
                        p_nro, v_estado;
    END IF;

    SELECT count(*) INTO v_renglones FROM renglon_transferencia WHERE nro_transferencia = p_nro;
    IF v_renglones = 0 THEN
        RAISE EXCEPTION 'La transferencia % no tiene renglones (RN-11)', p_nro;
    END IF;

    -- 2. Bloquear el stock del depósito de los vinos involucrados (orden fijo).
    PERFORM 1
       FROM stock_deposito d
       JOIN renglon_transferencia r ON r.cod_vino = d.cod_vino
      WHERE r.nro_transferencia = p_nro
      ORDER BY d.cod_vino
        FOR UPDATE OF d;

    -- 3. Verificar que haya stock suficiente para TODOS los renglones.
    --    (Cubre también el caso del vino sin fila en stock_deposito, que un
    --    UPDATE ... FROM simplemente ignoraría.)
    SELECT r.cod_vino, r.cantidad AS pedido, COALESCE(d.cantidad, 0) AS disponible
      INTO v_faltante
      FROM renglon_transferencia r
      LEFT JOIN stock_deposito d ON d.cod_vino = r.cod_vino
     WHERE r.nro_transferencia = p_nro
       AND COALESCE(d.cantidad, 0) < r.cantidad
     ORDER BY r.cod_vino
     LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'Stock insuficiente en el depósito central para el vino % (pedido %, disponible %). La transferencia % no se procesó (RN-11)',
                        v_faltante.cod_vino, v_faltante.pedido, v_faltante.disponible, p_nro;
    END IF;

    -- 4. Descontar del depósito.
    UPDATE stock_deposito d
       SET cantidad = d.cantidad - r.cantidad
      FROM renglon_transferencia r
     WHERE r.nro_transferencia = p_nro
       AND d.cod_vino = r.cod_vino;

    -- 5. Sumar a la sala (crea la fila si no existía).
    INSERT INTO stock_sala (id_sala, cod_vino, cantidad)
    SELECT v_sala, cod_vino, cantidad
      FROM renglon_transferencia
     WHERE nro_transferencia = p_nro
    ON CONFLICT (id_sala, cod_vino)
    DO UPDATE SET cantidad = stock_sala.cantidad + EXCLUDED.cantidad;

    -- 6. Cambiar el estado (el trigger valida la transición).
    PERFORM set_config('bodega.procesando', 'si', true);
    UPDATE transferencia SET estado = 'procesado' WHERE nro_transferencia = p_nro;
    PERFORM set_config('bodega.procesando', 'no', true);
END;
$$;

COMMENT ON PROCEDURE sp_procesar_transferencia(INTEGER) IS
    'RN-11: mueve stock del depósito a la sala para una transferencia terminada y la pasa a procesada (todo o nada).';
