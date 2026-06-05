#!/bin/bash
# =============================================================
# RoSeMAN Update Script
#
# Pulls latest Docker images and restarts services.
# Run manually: sudo /opt/roseman/scripts/update.sh
#
# Requires internet connection.
# =============================================================
set -euo pipefail

ROSEMAN_DIR="/opt/roseman"

echo "=== RoSeMAN Update — $(date) ==="

cd "${ROSEMAN_DIR}"

# Pull latest images
echo "Pulling latest Docker images..."
docker compose pull

# Restart services with new images
echo "Restarting services..."
docker compose up -d --remove-orphans

# Clean up unused images
echo "Cleaning up unused images..."
docker image prune -f

echo "=== Update Complete — $(date) ==="
echo ""
echo "Useful commands:"
echo "  cd ${ROSEMAN_DIR} && docker compose logs -f    # view logs"
echo "  cd ${ROSEMAN_DIR} && docker compose ps          # check status"
