CREATE TABLE localidad (
    codigo_postal VARCHAR(10) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    provincia VARCHAR(100) NOT NULL,
    encargado_regional VARCHAR(100)
);

CREATE TABLE cepa (
    id_cepa SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    tipo VARCHAR(50) NOT NULL
);

CREATE TABLE bodega (
    cuit CHAR(11) PRIMARY KEY,
    razon_social VARCHAR(150) NOT NULL,
    domicilio VARCHAR(150) NOT NULL
);