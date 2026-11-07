CREATE TABLE stock_deposito (
    cod_vino INT PRIMARY KEY REFERENCES vino(cod_vino),
    cantidad INT NOT NULL CHECK (cantidad >= 0)
);

-- Vista fundamental para calcular el stock total que luego consulta la API
CREATE OR REPLACE VIEW vw_stock_total_vino AS
SELECT 
    v.cod_vino,
    v.nombre,
    v.anada,
    COALESCE(sd.cantidad, 0) AS stock_deposito,
    COALESCE(SUM(ss.cant), 0) AS stock_en_salas,
    COALESCE(sd.cantidad, 0) + COALESCE(SUM(ss.cant), 0) AS stock_total
FROM vino v
LEFT JOIN stock_deposito sd ON v.cod_vino = sd.cod_vino
LEFT JOIN stock_sala ss ON v.cod_vino = ss.cod_vino
GROUP BY v.cod_vino, v.nombre, v.anada, sd.cantidad;