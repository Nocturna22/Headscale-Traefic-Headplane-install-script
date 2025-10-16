#!/bin/bash

echo "🧹 Headscale & Headplane Uninstaller"
echo "-----------------------------------"

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# Confirm uninstallation
read -p "This will remove all containers, data, and config files for Headscale & Headplane. Continue? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Uninstall aborted."
    exit 0
fi

# Check if Docker Compose file exists
if [[ ! -f "headscale/docker-compose.yaml" ]]; then
    echo "No docker-compose.yaml found in ./headscale/"
    read -p "Enter the path to your headscale directory (default: ./headscale): " CUSTOM_PATH
    HEADSCALE_DIR="${CUSTOM_PATH:-./headscale}"
else
    HEADSCALE_DIR="./headscale"
fi

cd "$HEADSCALE_DIR" || { echo "❌ Directory $HEADSCALE_DIR not found."; exit 1; }

# Stop and remove containers
echo "🛑 Stopping Docker containers..."
docker compose down -v --remove-orphans

# Optionally remove Docker images
read -p "Do you also want to remove Docker images for headscale, headplane, and traefik? (y/N): " REMOVE_IMAGES
if [[ "$REMOVE_IMAGES" =~ ^[Yy]$ ]]; then
    echo "🗑 Removing images..."
    docker rmi headscale/headscale:latest ghcr.io/tale/headplane:latest traefik:latest 2>/dev/null || true
fi

# Optionally remove persistent data and config
read -p "Do you want to delete the headscale directory and all configuration/data files? (y/N): " REMOVE_FILES
if [[ "$REMOVE_FILES" =~ ^[Yy]$ ]]; then
    echo "🧨 Deleting files and directories..."
    cd ..
    rm -rf "$HEADSCALE_DIR"
fi

# Optionally clean up unused Docker resources
read -p "Clean up unused Docker volumes and networks? (y/N): " PRUNE
if [[ "$PRUNE" =~ ^[Yy]$ ]]; then
    echo "🧽 Pruning Docker system..."
    docker system prune -f
fi

echo "✅ Uninstallation complete."
echo "All containers stopped and resources cleaned up."

# Summary
echo "-----------------------------------"
echo "If you plan to reinstall, make sure to run your install script again."
echo "Traefik certificates (if any) were stored in ./headscale/letsencrypt — deleted if you confirmed file removal."
echo "-----------------------------------"
