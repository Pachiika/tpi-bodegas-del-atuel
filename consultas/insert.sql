-- =====================================================================
-- BODEGAS DEL ATUEL - CONSULTAS DE INSERCIÓN (consultas/insert.sql)
-- =====================================================================

-- I1: Insertar una nueva localidad
INSERT INTO localidad (codigo_postal, nombre, provincia, encargado_regional)
VALUES ('5600', 'San Rafael', 'Mendoza', 'Juan Pérez');

-- I2: Insertar una sala de venta
INSERT INTO sala_venta (calle, numero, dia_cierre, cp_localidad)
VALUES ('Av. Hipólito Yrigoyen', '1500', 'Domingo', '5600');

-- I3: Insertar un empleado asociado a la sala
INSERT INTO empleado (cuit, nombre, fecha_ingreso, salario, id_sala)
VALUES ('20351234567', 'Carlos Gómez', '2023-01-15', 450000.00, 1);

-- I4: Insertar un nuevo cliente (ej: Socio)
INSERT INTO cliente (nombre_o_razon_social, tipo_doc, nro_doc, direccion, cp_localidad, fecha_alta, tipo_cliente)
VALUES ('María Giménez', 'DNI', '32123456', 'Mitre 250', '5600', '2024-02-10', 'socio');

-- I5: Insertar un vino vinculado a una bodega existente
INSERT INTO vino (nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
VALUES ('Atuel Reserva Malbec', 'tinto', 2021, 750, 14.50, 8500.00, '30712345671');

-- I6: Registrar un stock inicial en el depósito central
INSERT INTO stock_deposito (cod_vino, cantidad)
VALUES (1, 5000);
