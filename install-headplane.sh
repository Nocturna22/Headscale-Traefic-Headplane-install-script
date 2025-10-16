#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# Prompt the user for the full domain (including subdomain)
read -p "Enter your full domain (e.g., headscale.example.com): " FULL_DOMAIN

# Prompt for admin email (used by Let's Encrypt)
echo ""
echo "⚠️  Important: Use the correct Syntax — Let's Encrypt will refuse invalid emails."
echo "Example: admin@example.com"
read -p "Enter your email address for Let's Encrypt: " ADMIN_EMAIL

# Prompt for timezone
echo ""
echo "🌍 Set your timezone (default: Europe/Berlin)"
read -p "Enter your timezone (e.g., Europe/Berlin): " TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Berlin}

# Create the directory structure
mkdir -p headscale/data headscale/configs/headscale headscale/configs/headplane headscale/letsencrypt

# Create the docker-compose.yaml file
cat <<EOF > headscale/docker-compose.yaml
services:
  headscale:
    image: 'headscale/headscale:latest'
    container_name: 'headscale'
    restart: 'unless-stopped'
    command: 'serve'
    volumes:
      - './data:/var/lib/headscale'
      - './configs/headscale:/etc/headscale'
    environment:
      TZ: '$TIMEZONE'
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.headscale.rule=Host(\`$FULL_DOMAIN\`)"
      - "traefik.http.routers.headscale.tls.certresolver=myresolver"
      - "traefik.http.routers.headscale.entrypoints=websecure"
      - "traefik.http.routers.headscale.tls=true"
      - "traefik.http.services.headscale.loadbalancer.server.port=8080"

  headplane:
    image: 'ghcr.io/tale/headplane:latest'
    container_name: 'headplane'
    restart: 'unless-stopped'
    volumes:
      - './configs/headplane/config.yaml:/etc/headplane/config.yaml:ro'
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.headplane.rule=Host(\`$FULL_DOMAIN\`) && PathPrefix(\`/admin\`)"
      - "traefik.http.routers.headplane.entrypoints=websecure"
      - "traefik.http.routers.headplane.tls=true"
      - "traefik.http.services.headplane.loadbalancer.server.port=3000"

  traefik:
    image: "traefik:latest"
    container_name: "traefik"
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entryPoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entryPoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.myresolver.acme.email=$ADMIN_EMAIL"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "./letsencrypt:/letsencrypt"
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
EOF

# Create the config.yaml file for Headscale
cat <<EOF > headscale/configs/headscale/config.yaml
server_url: https://$FULL_DOMAIN
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 127.0.0.1:50443
grpc_allow_insecure: false
noise:
  private_key_path: /var/lib/headscale/noise_private.key
prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
  allocation: sequential
derp:
  server:
    enabled: true
    region_id: 999
    region_code: "headscale"
    region_name: "Headscale Embedded DERP"
    stun_listen_addr: "0.0.0.0:3478"
    private_key_path: /var/lib/headscale/derp_server_private.key
    automatically_add_embedded_derp_region: true
    ipv4: 1.2.3.4
    ipv6: 2001:db8::1
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  auto_update_enabled: true
  update_frequency: 24h
disable_check_updates: false
ephemeral_node_inactivity_timeout: 30m
database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite
acme_url: https://acme-v02.api.letsencrypt.org/directory
acme_email: "$ADMIN_EMAIL"
tls_letsencrypt_cache_dir: /var/lib/headscale/cache
tls_letsencrypt_challenge_type: HTTP-01
tls_letsencrypt_listen: ":http"
log:
  format: text
  level: info
dns:
  magic_dns: true
  base_domain: example.com
  nameservers:
    global:
      - 1.1.1.1
      - 1.0.0.1
unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"
EOF

# Notify the user
echo "Deployment files created in 'headscale' directory."

# Start Headscale and Traefik first
if ! docker compose -f headscale/docker-compose.yaml up -d headscale traefik; then
    echo "Failed to start Docker containers. Exiting..."
    exit 1
fi

# Wait for Headscale to start
sleep 10

# Create the API key and capture the output
API_KEY=$(docker exec headscale headscale apikey create | awk '{print $NF}')
if [ -z "$API_KEY" ]; then
    echo "Failed to create API Key. Exiting..."
    exit 1
fi

# Generate random cookie secret
COOKIE_SECRET=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)

# Save the API key for later use
echo "HEADSCALE_API_KEY=$API_KEY" > headscale/.env

# Create Headplane config.yaml using the correct structure
cat <<EOF > headscale/configs/headplane/config.yaml
server:
  host: "0.0.0.0"
  log_level: "info"
  cookie_secure: false
  cookie_secret: "${COOKIE_SECRET}"
  port: "3000"

headscale:
  url: "https://$FULL_DOMAIN"
  api_key: "${API_KEY}"
  insecure: false
  config_strict: false

ui:
  base_path: "/admin"
  theme: "light"
EOF

# Start Headplane
docker compose -f headscale/docker-compose.yaml up -d headplane

# Display final info
echo "--------------------------------------------------"
echo "Setup complete!"
echo "Headscale is running at: https://$FULL_DOMAIN"
echo "Headplane UI is available at: https://$FULL_DOMAIN/admin"
echo ""
echo "🔑 Your Headscale API Key:"
echo "$API_KEY"
echo ""
echo "Open https://$FULL_DOMAIN/admin and paste it there. 🤌"
echo "--------------------------------------------------"
