# 🧠 Headscale + Headplane + Traefik Setup

A simple installer for **Headscale**, **Headplane**, and **Traefik** — running in Docker.  
Automatically sets up HTTPS (via Let’s Encrypt), generates API keys, configures the UI, and more.

---

## 🚀 Quickstart

### Install

```bash
sudo chmod +x install-headscale.sh
sudo ./install-headscale.sh
```

During installation, you’ll be prompted for:

    Domain (e.g., headscale.example.com)
    Email (for Let’s Encrypt SSL)

The installer will build all configs, start Headscale, Traefik, and Headplane, and display your API key at the end.

### Uninstall

```bash
sudo chmod +x uninstall-headscale.sh
sudo ./uninstall-headscale.sh
```

This script will stop containers, remove volumes, delete configs/data, and optionally prune unused Docker resources.

### 🌐 Access

    Headscale API: https://your-domain.com

    Headplane Web UI: https://your-domain.com/admin

Your API Key is displayed at the end of install and also saved to headscale/.env.

### 📁 Directory Structure

```bash
headscale/
├── configs/
│   ├── headscale/config.yaml
│   └── headplane/config.yaml
├── data/
├── letsencrypt/
├── docker-compose.yaml
└── .env
```

### ✅ Working Configuration (Image Versions)

Here are the versions confirmed working in this setup:

```bash
headplane:
  image: 'ghcr.io/tale/headplane:0.6.1'

headscale:
  image: 'headscale/headscale:v0.26.1'

traefik:
  image: 'traefik:v3.5.3'
```

You can pin these in your docker-compose.yaml to avoid surprises from latest tags.

### 🛠️ Troubleshooting

    View logs:

docker logs -f headscale
docker logs -f headplane
docker logs -f traefik


### 🧩 License & Notes

This setup script is free to use and adapt.
Headscale, Headplane, and Traefik are each under their own open-source licenses — check their docs.
Pinning versions (instead of latest) is recommended for stability if something does not work.

Enjoy your self-hosted Tailscale control plane!
