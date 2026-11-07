CREATE TABLE sala_venta (
    id_sala SERIAL PRIMARY KEY,
    calle VARCHAR(100) NOT NULL,
    numero VARCHAR(20) NOT NULL,
    dia_cierre VARCHAR(20) NOT NULL,
    cp_localidad VARCHAR(10) REFERENCES localidad(codigo_postal)
);

CREATE TABLE empleado (
    cuit CHAR(11) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    fecha_ingreso DATE NOT NULL,
    salario NUMERIC(10,2) NOT NULL,
    id_sala INT REFERENCES sala_venta(id_sala)
);

CREATE TABLE cliente (
    id_cliente SERIAL PRIMARY KEY,
    nombre_o_razon_social VARCHAR(150) NOT NULL,
    tipo_doc VARCHAR(20) NOT NULL,
    nro_doc VARCHAR(20) NOT NULL,
    direccion VARCHAR(150) NOT NULL,
    cp_localidad VARCHAR(10) REFERENCES localidad(codigo_postal),
    fecha_alta DATE NOT NULL,
    tipo_cliente VARCHAR(30) NOT NULL
);

CREATE TABLE stock_sala (
    id_sala INT REFERENCES sala_venta(id_sala),
    cod_vino INT REFERENCES vino(cod_vino),
    cant INT NOT NULL CHECK (cant >= 0),
    PRIMARY KEY (id_sala, cod_vino)
);