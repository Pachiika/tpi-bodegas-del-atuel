const API_URL = "http://localhost:8000";

async function cargarStock() {
    try {
        const response = await fetch(`${API_URL}/stock`);
        const datos = await response.json();
        
        const tbody = document.querySelector("#tabla-stock tbody");
        tbody.innerHTML = "";

        datos.forEach(vino => {
            const tr = document.createElement("tr");
            tr.innerHTML = `
                <td>${vino.cod_vino}</td>
                <td>${vino.nombre}</td>
                <td>${vino.anada}</td>
                <td>${vino.stock_deposito}</td>
                <td>${vino.stock_en_salas}</td>
                <td><strong>${vino.stock_total}</strong></td>
            `;
            tbody.appendChild(tr);
        });
    } catch (error) {
        console.error("Error al cargar el stock:", error);
    }
}

// Cargar stock al iniciar la página
document.addEventListener("DOMContentLoaded", cargarStock);