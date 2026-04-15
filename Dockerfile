FROM nginx:1-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY .htpasswd /etc/nginx/.htpasswd
COPY public /usr/share/nginx/html
EXPOSE 8080
