-- =====================================================================
-- BODEGAS DEL ATUEL - CONSULTAS DE ACTUALIZACIÓN (consultas/update.sql)
-- =====================================================================

-- U1: Actualizar el precio de un vino (Esto disparará automáticamente el trigger de auditoría RN-13)
UPDATE vino 
SET precio = 9200.00 
WHERE cod_vino = 1;

-- U2: Modificar el salario de un empleado
UPDATE empleado 
SET salario = 490000.00 
WHERE cuit = '20351234567';

-- U3: Actualizar el encargado regional de una localidad
UPDATE localidad 
SET encargado_regional = 'Ana Rodríguez' 
WHERE codigo_postal = '5600';

-- U4: Cambiar el estado de un documento de ingreso a 'terminado'
UPDATE ingreso 
SET estado = 'terminado' 
WHERE codigo_ingreso = 1;

-- U5: Actualizar la dirección de un cliente
UPDATE cliente 
SET direccion = 'Belgrano 1200' 
WHERE id_cliente = 1;

-- U6: Modificar el stock de una sala de venta directamente por inventario físico
UPDATE stock_sala 
SET cantidad = cantidad + 50 
WHERE id_sala = 1 AND cod_vino = 1;