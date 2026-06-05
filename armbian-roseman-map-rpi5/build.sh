#!/bin/bash
# =============================================================
# Build Armbian image for Raspberry Pi 5 + RoSeMAN + Map
#
# This script:
#   1. Syncs build configs to the Armbian build tree
#   2. Syncs overlay files (Docker images, SPA, configs)
#   3. Runs the Armbian build
#
# Prerequisites:
#   - Run prepare-docker-images.sh first
#   - Run build-map.sh first (or have SPA files in overlay/)
#   - Armbian build repo cloned at ../armbian-build
#
# Usage:
#   ./build.sh
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/../armbian-build"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Validate prerequisites ──────────────────────────────────────
if [[ ! -d "${BUILD_DIR}" ]]; then
    info "Armbian build directory not found. Cloning..."
    git clone --depth 1 https://github.com/armbian/build.git "${BUILD_DIR}"
fi

if [[ ! -f "${BUILD_DIR}/compile.sh" ]]; then
    error "compile.sh not found in ${BUILD_DIR}"
fi

# Check overlay directory exists
if [[ ! -d "${SCRIPT_DIR}/overlay" ]]; then
    error "Overlay directory not found: ${SCRIPT_DIR}/overlay"
    error "Run prepare-docker-images.sh and build-map.sh first"
fi

# Check Docker images exist in overlay
if [[ ! -d "${SCRIPT_DIR}/overlay/opt/roseman/docker-images" ]] || \
   ! ls "${SCRIPT_DIR}/overlay/opt/roseman/docker-images/"*.tar &>/dev/null; then
    warn "No Docker image tar files found in overlay"
    warn "Run ./prepare-docker-images.sh first for offline deployment"
    warn "Continuing without offline images (will pull on first boot)"
fi

# ── Sync build config ──────────────────────────────────────────
info "Syncing build configuration..."

# Copy board config to Armbian userpatches
mkdir -p "${BUILD_DIR}/userpatches"
cp "${SCRIPT_DIR}/build-config/config-rpi5-roseman.conf.sh" \
   "${BUILD_DIR}/userpatches/config-rpi5-roseman.conf.sh"

# Copy customize-image.sh
cp "${SCRIPT_DIR}/build-config/customize-image.sh" \
   "${BUILD_DIR}/userpatches/customize-image.sh"
chmod +x "${BUILD_DIR}/userpatches/customize-image.sh"

# ── Sync overlay ────────────────────────────────────────────────
info "Syncing overlay files..."

# Create overlay structure in Armbian build tree
OVERLAY_DEST="${BUILD_DIR}/userpatches/overlay"

# Clean previous overlay (remove stale files, including hidden)
info "Cleaning previous overlay..."
rm -rf "${OVERLAY_DEST}"

mkdir -p "${OVERLAY_DEST}/etc/nginx/sites-available"
mkdir -p "${OVERLAY_DEST}/etc/nginx/sites-enabled"
mkdir -p "${OVERLAY_DEST}/etc/systemd/system"
mkdir -p "${OVERLAY_DEST}/opt/roseman/scripts"
mkdir -p "${OVERLAY_DEST}/opt/roseman/docker-images"
mkdir -p "${OVERLAY_DEST}/opt/roseman/dump"
mkdir -p "${OVERLAY_DEST}/opt/roseman/src"
mkdir -p "${OVERLAY_DEST}/var/www/sensors-social"

# Copy nginx config (sensors-social only)
cp "${SCRIPT_DIR}/build-config/nginx-sensors-social.conf" \
   "${OVERLAY_DEST}/etc/nginx/sites-available/sensors-social"

# Copy systemd services
cp "${SCRIPT_DIR}/build-config/roseman-firstboot.service" \
   "${OVERLAY_DEST}/etc/systemd/system/roseman-firstboot.service"
cp "${SCRIPT_DIR}/build-config/wifi-setup.service" \
   "${OVERLAY_DEST}/etc/systemd/system/wifi-setup.service"

# Copy scripts
cp "${SCRIPT_DIR}/build-config/firstboot.sh" \
   "${OVERLAY_DEST}/opt/roseman/scripts/firstboot.sh"
cp "${SCRIPT_DIR}/build-config/update.sh" \
   "${OVERLAY_DEST}/opt/roseman/scripts/update.sh"
cp "${SCRIPT_DIR}/build-config/restore.sh" \
   "${OVERLAY_DEST}/opt/roseman/scripts/restore.sh"
cp "${SCRIPT_DIR}/build-config/wifi-setup.sh" \
   "${OVERLAY_DEST}/opt/roseman/scripts/wifi-setup.sh"

# Copy docker-compose.yml
cp "${SCRIPT_DIR}/build-config/docker-compose.yml" \
   "${OVERLAY_DEST}/opt/roseman/docker-compose.yml"

# Copy .env templates
cp "${SCRIPT_DIR}/build-config/.env.example" \
   "${OVERLAY_DEST}/opt/roseman/.env.example"
cp "${SCRIPT_DIR}/build-config/.env.polkadot.example" \
   "${OVERLAY_DEST}/opt/roseman/.env.polkadot.example"

# Copy Docker images (if prepared)
if ls "${SCRIPT_DIR}/overlay/opt/roseman/docker-images/"*.tar &>/dev/null; then
    info "Copying Docker image tar files..."
    cp "${SCRIPT_DIR}/overlay/opt/roseman/docker-images/"*.tar \
       "${OVERLAY_DEST}/opt/roseman/docker-images/"
fi

# Copy SPA files (if built)
if [[ -d "${SCRIPT_DIR}/overlay/var/www/sensors-social" ]] && \
   ls "${SCRIPT_DIR}/overlay/var/www/sensors-social/"*.html &>/dev/null; then
    info "Copying sensors.social SPA files..."
    rm -rf "${OVERLAY_DEST}/var/www/sensors-social"
    cp -r "${SCRIPT_DIR}/overlay/var/www/sensors-social" \
       "${OVERLAY_DEST}/var/www/sensors-social"
fi

# Copy RoSeMAN source/config files from overlay
for envfile in .env.example .env.polkadot.example; do
    src="${SCRIPT_DIR}/overlay/opt/roseman/${envfile}"
    if [[ -f "${src}" ]]; then
        cp "${src}" "${OVERLAY_DEST}/opt/roseman/${envfile}"
    fi
done

# Copy RoSeMAN source files from overlay
if [[ -d "${SCRIPT_DIR}/overlay/opt/roseman/src" ]]; then
    rm -rf "${OVERLAY_DEST}/opt/roseman/src"
    cp -r "${SCRIPT_DIR}/overlay/opt/roseman/src" \
       "${OVERLAY_DEST}/opt/roseman/src"
fi

# ── Build Armbian image ─────────────────────────────────────────
info ""
info "========================================="
info "  Building Armbian for RPi 5 + RoSeMAN"
info "========================================="
info "  BOARD:    rpi4b (covers RPi 3B+, 4, 5)"
info "  BRANCH:   current (rpi-6.18.y kernel)"
info "  RELEASE:  noble (Ubuntu 24.04)"
info ""
info "  WiFi Setup: wpa_supplicant.conf on RPICFG partition"
info "  Map:        sensors.social on port 80"
info "========================================="
info ""

cd "${BUILD_DIR}"
./compile.sh rpi5-roseman

info ""
info "========================================="
info "  Build complete!"
info "========================================="
info "  Image files are in: ${BUILD_DIR}/output/images/"
info "========================================="
