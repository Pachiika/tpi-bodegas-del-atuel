FROM nginx:1.27-alpine
COPY . /usr/share/nginx/html
COPY docker-entrypoint.sh /docker-entrypoint.d/40-config-api.sh
RUN chmod +x /docker-entrypoint.d/40-config-api.sh && rm /usr/share/nginx/html/Dockerfile /usr/share/nginx/html/docker-entrypoint.sh
EXPOSE 80
