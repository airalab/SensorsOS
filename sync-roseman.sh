#!/bin/bash
# =============================================================
# sync-roseman.sh
#
# Syncs RoSeMAN source code and config from the upstream repo
# into the overlay directories of both OPI5 and RPi5 builds.
#
# REQUIRED before building — overlay/opt/roseman/src/ and related
# files are not tracked in git and must be populated by this script.
#
# Usage:
#   ./sync-roseman.sh [/path/to/RoSeMAN]
#
#   If no path is given, clones from GitHub (shallow).
#   If a local path is given, copies from that directory.
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROSEMAN_SRC=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Source directory ─────────────────────────────────────────────
if [[ $# -ge 1 ]]; then
    ROSEMAN_SRC="$1"
    if [[ ! -d "${ROSEMAN_SRC}" ]]; then
        error "Directory not found: ${ROSEMAN_SRC}"
    fi
    if [[ ! -f "${ROSEMAN_SRC}/package.json" ]]; then
        error "Does not look like a RoSeMAN repo: ${ROSEMAN_SRC}"
    fi
    info "Using local RoSeMAN: ${ROSEMAN_SRC}"
else
    # Clone shallow copy
    ROSEMAN_SRC=$(mktemp -d)
    info "Cloning RoSeMAN from GitHub..."
    git clone --depth 1 https://github.com/falconexe/RoSeMAN.git "${ROSEMAN_SRC}"
fi

# ── Files to sync (generated, not in git) ────────────────────────
SYNC_FILES=(
    "package.json"
    "package-lock.json"
    "Dockerfile"
    "nest-cli.json"
    "tsconfig.json"
    "tsconfig.build.json"
)

SYNC_DIRS=(
    "src"
)

# Config templates (agents.json, config.json)
if [[ -d "${ROSEMAN_SRC}/config" ]]; then
    SYNC_DIRS+=("config")
fi

# ── Sync function ────────────────────────────────────────────────
sync_to_overlay() {
    local TARGET="$1"
    local OVERLAY_ROSEMAN="${TARGET}/overlay/opt/roseman"

    if [[ ! -d "${TARGET}" ]]; then
        warn "Target directory not found, skipping: ${TARGET}"
        return
    fi

    info "Syncing to: ${TARGET}"

    # Create overlay directories
    mkdir -p "${OVERLAY_ROSEMAN}/src"
    mkdir -p "${OVERLAY_ROSEMAN}/docker-images"

    # Copy files
    for f in "${SYNC_FILES[@]}"; do
        if [[ -f "${ROSEMAN_SRC}/${f}" ]]; then
            cp "${ROSEMAN_SRC}/${f}" "${OVERLAY_ROSEMAN}/${f}"
            info "  Updated: ${f}"
        else
            warn "  Missing: ${f}"
        fi
    done

    # Copy directories
    for d in "${SYNC_DIRS[@]}"; do
        if [[ -d "${ROSEMAN_SRC}/${d}" ]]; then
            rm -rf "${OVERLAY_ROSEMAN}/${d}"
            cp -r "${ROSEMAN_SRC}/${d}" "${OVERLAY_ROSEMAN}/${d}"
            info "  Updated: ${d}/"
        else
            warn "  Missing: ${d}/"
        fi
    done
}

# ── Sync to both targets ─────────────────────────────────────────
sync_to_overlay "${SCRIPT_DIR}/armbian-roseman-map-opi5"
sync_to_overlay "${SCRIPT_DIR}/armbian-roseman-map-rpi5"

# ── Cleanup ──────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    info "Cleaning up cloned repo..."
    rm -rf "${ROSEMAN_SRC}"
fi

echo ""
info "========================================="
info "  RoSeMAN source synced!"
info "========================================="
info ""
info "  Next steps (for each board):"
info "    1. ./prepare-docker-images.sh"
info "    2. ./build.sh"
info "========================================="
