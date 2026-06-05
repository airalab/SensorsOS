#!/bin/bash
# =============================================================
# RoSeMAN firstboot script
#
# Runs once on first boot:
#   1. Waits for Docker daemon
#   2. Loads pre-saved Docker images from tar (offline)
#   3. Starts docker compose
#   4. Cleans up tar files
#   5. Disables itself
# =============================================================
set -euo pipefail

ROSEMAN_DIR="/opt/roseman"
IMAGES_DIR="${ROSEMAN_DIR}/docker-images"
LOG="/var/log/roseman-firstboot.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

log "=== RoSeMAN firstboot start ==="

# ── Step 1: Wait for Docker ──────────────────────────────────
log "Waiting for Docker daemon..."
MAX_WAIT=120
ELAPSED=0
while ! docker info &>/dev/null; do
	sleep 2
	ELAPSED=$((ELAPSED + 2))
	if [[ ${ELAPSED} -ge ${MAX_WAIT} ]]; then
		log "ERROR: Docker did not start within ${MAX_WAIT}s"
		exit 1
	fi
done
log "Docker is ready."

# ── Step 2: Load Docker images from tar ──────────────────────
if [[ -d "${IMAGES_DIR}" ]] && ls "${IMAGES_DIR}"/*.tar &>/dev/null; then
	for tar_file in "${IMAGES_DIR}"/*.tar; do
		log "Loading image from $(basename "${tar_file}")..."
		docker load -i "${tar_file}" 2>&1 | tee -a "${LOG}"
		log "Loaded: $(basename "${tar_file}")"
	done
else
	log "No pre-saved Docker images found in ${IMAGES_DIR}"
	log "Will attempt to pull images (requires internet)..."
fi

# ── Step 3: Start RoSeMAN services ───────────────────────────
cd "${ROSEMAN_DIR}"

log "Starting RoSeMAN services..."
docker compose up -d 2>&1 | tee -a "${LOG}"

# ── Step 4: Wait for health check ────────────────────────────
log "Waiting for services to become healthy..."
MAX_WAIT=180
ELAPSED=0
while [[ ${ELAPSED} -lt ${MAX_WAIT} ]]; do
	if docker compose ps 2>/dev/null | grep -q "healthy"; then
		log "Services are healthy."
		break
	fi
	sleep 5
	ELAPSED=$((ELAPSED + 5))
done

if [[ ${ELAPSED} -ge ${MAX_WAIT} ]]; then
	log "WARNING: Not all services became healthy within ${MAX_WAIT}s"
	log "Check: cd ${ROSEMAN_DIR} && docker compose ps"
fi

# ── Step 5: Clean up tar files ───────────────────────────────
if [[ -d "${IMAGES_DIR}" ]]; then
	log "Removing Docker image tar files to free space..."
	rm -rf "${IMAGES_DIR}"/*.tar
	log "Cleaned up."
fi

# ── Step 6: Print info ───────────────────────────────────────
MONGO_PASSWORD=""
if [[ -f "${ROSEMAN_DIR}/.mongo_password_generated" ]]; then
	MONGO_PASSWORD=$(cat "${ROSEMAN_DIR}/.mongo_password_generated")
fi

APP_PORT=3000
if [[ -f "${ROSEMAN_DIR}/.env" ]]; then
	APP_PORT=$(grep '^PORT=' "${ROSEMAN_DIR}/.env" | cut -d= -f2)
	APP_PORT=${APP_PORT:-3000}
fi

IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

log ""
log "========================================="
log "  RoSeMAN is running!"
log "========================================="
log "  Map:        http://${IP_ADDR}/"
log "  REST API:   http://${IP_ADDR}:${APP_PORT}/api"
log "  Metrics:    http://${IP_ADDR}:${APP_PORT}/metrics"
log "  MongoDB:    admin / ${MONGO_PASSWORD}"
log "  Config:     ${ROSEMAN_DIR}"
log "  Update:     ${ROSEMAN_DIR}/scripts/update.sh"
log "========================================="

# ── Step 7: Disable this service ─────────────────────────────
systemctl disable roseman-firstboot.service

log "Firstboot service disabled. Will not run again."
log "=== RoSeMAN firstboot complete ==="
