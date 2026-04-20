FROM nginx:1-alpine

# Install Python and pip for the Tornado annotation backend
RUN apk add --no-cache python3 py3-pip

# Install Tornado
COPY annotation/requirements.txt /app/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /app/requirements.txt

# Copy annotation server
COPY annotation/server.py /app/server.py

# Copy nginx config and static content
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY .htpasswd /etc/nginx/.htpasswd
COPY public /usr/share/nginx/html

# Copy entrypoint script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080
CMD ["/start.sh"]
