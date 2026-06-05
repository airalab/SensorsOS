#!/bin/bash
# =============================================================
# prepare-docker-images.sh
#
# Pulls Docker images for linux/arm64 and saves them as tar files
# into the overlay directory for offline deployment on RPi 5.
#
# Run this BEFORE building the Armbian image.
# Requires: Docker with buildx + QEMU/binfmt support
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OVERLAY_IMAGES_DIR="${SCRIPT_DIR}/overlay/opt/roseman/docker-images"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Check Docker ──────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    error "Docker is not installed. Install it first: https://get.docker.com"
fi

if ! docker info &>/dev/null; then
    error "Docker daemon is not running."
fi

info "Docker: $(docker --version)"

# ── Check / Setup QEMU for arm64 ─────────────────────────────
if ! docker buildx inspect default 2>/dev/null | grep -q "arm64"; then
    info "Setting up Docker buildx with QEMU for arm64..."
    docker run --privileged --rm tonistiigi/binfmt --install all
    docker buildx create --name multiarch --driver docker-container --use || true
    docker buildx inspect --bootstrap
fi

# ── Create output directory ───────────────────────────────────
mkdir -p "${OVERLAY_IMAGES_DIR}"

# ── Pull and save images ─────────────────────────────────────
PLATFORM="linux/arm64"

# MongoDB 8
info "Pulling mongo:8 for ${PLATFORM}..."
docker pull --platform "${PLATFORM}" mongo:8

info "Saving mongo:8 to tar..."
docker save mongo:8 -o "${OVERLAY_IMAGES_DIR}/mongo-8-arm64.tar"
MONGO_SIZE=$(du -sh "${OVERLAY_IMAGES_DIR}/mongo-8-arm64.tar" | cut -f1)
info "mongo:8 saved (${MONGO_SIZE})"

# RoSeMAN app image
info "Pulling ghcr.io/falconexe/roseman:docker for ${PLATFORM}..."
docker pull --platform "${PLATFORM}" ghcr.io/falconexe/roseman:docker

info "Saving ghcr.io/falconexe/roseman:docker to tar..."
docker save ghcr.io/falconexe/roseman:docker -o "${OVERLAY_IMAGES_DIR}/roseman-docker-arm64.tar"
ROSEMAN_SIZE=$(du -sh "${OVERLAY_IMAGES_DIR}/roseman-docker-arm64.tar" | cut -f1)
info "roseman:docker saved (${ROSEMAN_SIZE})"

# ── Summary ───────────────────────────────────────────────────
TOTAL_SIZE=$(du -sh "${OVERLAY_IMAGES_DIR}" | cut -f1)
echo ""
info "========================================="
info "  Docker images prepared for offline!"
info "========================================="
info "  Location: ${OVERLAY_IMAGES_DIR}"
info "  Total size: ${TOTAL_SIZE}"
info "  Files:"
ls -lh "${OVERLAY_IMAGES_DIR}"/*.tar 2>/dev/null | awk '{print "    " $NF " (" $5 ")"}'
info ""
info "  These will be loaded on first boot"
info "  and deleted afterwards to free SD card space."
info "========================================="
