CREATE TABLE vino (
    cod_vino SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('tinto', 'blanco', 'rosado', 'espumante')),
    anada INT NOT NULL,
    volumen_ml INT NOT NULL CHECK (volumen_ml IN (375, 750, 1500)),
    graduacion NUMERIC(4,2) NOT NULL CHECK (graduacion BETWEEN 5.00 AND 20.00),
    precio NUMERIC(10,2) NOT NULL CHECK (precio > 0),
    cuit_bodega CHAR(11) REFERENCES bodega(cuit)
);

CREATE TABLE composicion_vino (
    cod_vino INT REFERENCES vino(cod_vino) ON DELETE CASCADE,
    id_cepa INT REFERENCES cepa(id_cepa),
    porcentaje NUMERIC(5,2) NOT NULL,
    PRIMARY KEY (cod_vino, id_cepa)
);