[github_readme.md](https://github.com/user-attachments/files/34609318/github_readme.md)
# 🍷 Bodegas del Atuel — Trabajo Práctico Integrador (TPI)

Bienvenido al repositorio oficial del proyecto **Bodegas del Atuel**, un sistema diseñado para la gestión integral de bodegas, catálogo de vinos, control de calidad, clientes y transacciones comerciales.

---

## 📋 Tabla de Contenidos
- [Descripción del Proyecto](#-descripción-del-proyecto)
- [Estructura de la Base de Datos](#-estructura-de-la-base-de-datos)
- [Tecnologías Utilizadas](#-tecnologías-utilizadas)
- [Instalación y Configuración](#-instalación-y-configuración)
- [Documentación](#-documentación)
- [Autores](#-autores)

---

## 🚀 Descripción del Proyecto
**Bodegas del Atuel** es una solución orientada al sector vitivinícola que permite administrar de forma centralizada:
* La información institucional y de contacto de las bodegas.
* El portfolio de vinos, incluyendo su año de cosecha, precios y stock disponible.
* Las variedades de cepas y sus proporciones exactas en la elaboración de cortes o blends.
* Los controles y análisis físico-químicos de calidad realizados a los lotes.
* La gestión de clientes y el registro de comprobantes de venta.
* Sugerencias de maridaje asociadas a las características de los vinos.

---

## 🗄️ Estructura de la Base de Datos
El modelo relacional se compone de las siguientes entidades principales:
1. **`bodega`**: Datos institucionales y de contacto.
2. **`cepa`**: Catálogo de variedades de uva.
3. **`vinos`**: Portfolio de productos, precios y stock.
4. **`composicion_vino`**: Tabla asociativa para la definición de blends/cortes.
5. **`cliente`**: Registro de compradores y distribuidores.
6. **`comprobante`**: Operaciones comerciales y ventas.
7. **`analisis_calidad`**: Controles de laboratorio y graduación alcohólica.
8. **`maridaje`**: Recomendaciones gastronómicas.

Para ver el detalle técnico de cada campo y restricción, podés consultar el [Diccionario de Datos](./docs/diccionario_datos.md).

---

## 🛠️ Tecnologías Utilizadas
* **Base de Datos:** PostgreSQL / SQL Relacional.
* **Modelado de Datos:** DER / Modelo Relacional.
* **Control de Versiones:** Git & GitHub.

---

## ⚙️ Instalación y Configuración
1. Clonar el repositorio:
   ```bash
   git clone https://github.com/tu-usuario/bodegas-del-atuel.git
   ```
2. Crear la base de datos en tu motor SQL preferido.
3. Ejecutar los scripts de creación de tablas siguiendo el orden de las entidades definidas en el diccionario de datos.

---

## 📂 Documentación
* [Diccionario de Datos](./docs/diccionario_datos.md)

---

## 👥 Autores
María Paz Sosa, Lucas Rafael Diaz
