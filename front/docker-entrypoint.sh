#!/bin/sh
# Escribe la URL de la API en config.js al iniciar el contenedor.
set -e
if [ -n "$API_URL" ]; then
  echo "window.CONFIG = { API_URL: \"$API_URL\" };" > /usr/share/nginx/html/js/config.js
fi
