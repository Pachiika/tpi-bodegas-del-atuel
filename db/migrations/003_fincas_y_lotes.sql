CREATE TABLE finca (
    id_finca SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    superficie_ha NUMERIC(8,2) NOT NULL,
    departamento VARCHAR(100) NOT NULL,
    provincia VARCHAR(100) NOT NULL
);

CREATE TABLE parcela (
    id_finca INT REFERENCES finca(id_finca),
    nro_parcela INT,
    superficie_ha NUMERIC(8,2) NOT NULL,
    anio_plantacion INT NOT NULL,
    id_cepa INT REFERENCES cepa(id_cepa),
    PRIMARY KEY (id_finca, nro_parcela)
);

CREATE TABLE lote_uva (
    nro_lote SERIAL PRIMARY KEY,
    id_finca INT,
    nro_parcela INT,
    campania INT NOT NULL,
    fecha_cosecha DATE NOT NULL,
    kilos_cosechados NUMERIC(10,2) NOT NULL,
    cuit_bodega_destino CHAR(11) REFERENCES bodega(cuit),
    FOREIGN KEY (id_finca, nro_parcela) REFERENCES parcela(id_finca, nro_parcela)
);