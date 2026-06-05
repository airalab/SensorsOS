#!/bin/bash
# =============================================================
# Build the sensors.social SPA and copy to OPI5 overlay
#
# Builds directly on the host (requires Node.js 20+).
# Skips native module compilation and prerendering —
# not needed for local "remote" provider mode.
#
# Usage:
#   ./build-map.sh
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OVERLAY_WWW_DIR="${SCRIPT_DIR}/overlay/var/www/sensors-social"
BUILD_DIR=$(mktemp -d)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Check Node.js ──────────────────────────────────────────────
if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
    error "Node.js and npm are required. Install Node.js 20+ first."
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [[ "${NODE_VERSION}" -lt 20 ]]; then
    error "Node.js 20+ required, found $(node -v)"
fi

info "Node.js: $(node -v), npm: $(npm -v)"

# ── Clone ───────────────────────────────────────────────────────
info "Cloning sensors.social..."
git clone --depth 1 https://github.com/airalab/sensors.social.git "${BUILD_DIR}"

cd "${BUILD_DIR}"

# ── Overlay custom config ──────────────────────────────────────
info "Applying local config..."
mkdir -p src/config/local
cat > src/config/local/config.json << 'EOF'
{
  "REMOTE_PROVIDER": "/",
  "MAP": {
    "zoom": "3",
    "position": { "lat": "39.0277", "lng": "8.7891" },
    "measure": "pm10",
    "theme": {
      "light": "carto-light",
      "dark": "carto-dark",
      "satellite": "esri-imagery",
      "invertForDark": false
    }
  },
  "DEFAULT_TYPE_PROVIDER": "remote",
  "TITLE": "Local sensor map",
  "DESC": "Local sensor map"
}
EOF

# ── Install dependencies (skip native module builds) ───────────
info "Installing dependencies..."
npm install --ignore-scripts

# ── Disable prerendering (requires puppeteer/Chromium) ─────────
info "Disabling prerendering (not needed for local deployment)..."
sed -i '/prerender(/,/}),/s/^/\/\//' vite.config.js

# ── Build SPA ──────────────────────────────────────────────────
info "Building SPA..."
VITE_CONFIG_ENV=local npm run build

# ── Copy to overlay ────────────────────────────────────────────
info "Copying built files to overlay..."
rm -rf "${OVERLAY_WWW_DIR}"
mkdir -p "${OVERLAY_WWW_DIR}"
cp -r dist/. "${OVERLAY_WWW_DIR}/"

# ── Clean up ──────────────────────────────────────────────────
rm -rf "${BUILD_DIR}"

SIZE=$(du -sh "${OVERLAY_WWW_DIR}" | cut -f1)
FILE_COUNT=$(find "${OVERLAY_WWW_DIR}" -type f | wc -l)

info "========================================="
info "  SPA built successfully!"
info "========================================="
info "  Location: ${OVERLAY_WWW_DIR}"
info "  Size: ${SIZE}"
info "  Files: ${FILE_COUNT}"
info ""
info "  nginx will serve this at / on port 80"
info "  /api/ proxied to RoSeMAN REST API"
info "========================================="
