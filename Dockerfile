FROM nginx:1-alpine

# ---------------------------------------------------------------------------
# System deps: Python (Tornado backend) + curl (downloads oauth2-proxy binary)
# ---------------------------------------------------------------------------
RUN apk add --no-cache python3 py3-pip curl ca-certificates

# ---------------------------------------------------------------------------
# oauth2-proxy — sits in front of nginx and enforces Auth0 (Google SSO).
# Pinned to a specific release; bump when needed.
# ---------------------------------------------------------------------------
ARG OAUTH2_PROXY_VERSION=v7.15.2
ARG TARGETARCH=amd64
RUN curl -fsSL \
    "https://github.com/oauth2-proxy/oauth2-proxy/releases/download/${OAUTH2_PROXY_VERSION}/oauth2-proxy-${OAUTH2_PROXY_VERSION}.linux-${TARGETARCH}.tar.gz" \
    | tar -xz -C /tmp \
 && mv "/tmp/oauth2-proxy-${OAUTH2_PROXY_VERSION}.linux-${TARGETARCH}/oauth2-proxy" /usr/local/bin/oauth2-proxy \
 && chmod +x /usr/local/bin/oauth2-proxy \
 && rm -rf "/tmp/oauth2-proxy-${OAUTH2_PROXY_VERSION}.linux-${TARGETARCH}"

# ---------------------------------------------------------------------------
# Tornado annotation backend
# ---------------------------------------------------------------------------
COPY annotation/requirements.txt /app/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /app/requirements.txt

COPY annotation/server.py /app/server.py

# ---------------------------------------------------------------------------
# nginx config + static content + oauth2-proxy config
# ---------------------------------------------------------------------------
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY oauth2-proxy.cfg /etc/oauth2-proxy/oauth2-proxy.cfg
COPY public /usr/share/nginx/html

# ---------------------------------------------------------------------------
# Entrypoint — runs Tornado + nginx in the background, oauth2-proxy in fg
# ---------------------------------------------------------------------------
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Railway routes external traffic to whatever port the container binds to
# via the $PORT env var; oauth2-proxy owns that port now.
EXPOSE 8080
CMD ["/start.sh"]
