#!/bin/bash
# =============================================================
# build-map.sh
#
# Convenience wrapper — builds sensors.social SPA for all boards.
# For individual boards, run the script in each subdirectory:
#   cd armbian-roseman-map-opi5 && ./build-map.sh
#   cd armbian-roseman-map-rpi5 && ./build-map.sh
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================="
echo "  Building sensors.social SPA for all boards"
echo "================================="

for BOARD in armbian-roseman-map-opi5 armbian-roseman-map-rpi5; do
    BOARD_DIR="${SCRIPT_DIR}/${BOARD}"
    if [[ -x "${BOARD_DIR}/build-map.sh" ]]; then
        echo ""
        echo ">>> ${BOARD}"
        echo ""
        (cd "${BOARD_DIR}" && ./build-map.sh)
    else
        echo "WARNING: ${BOARD_DIR}/build-map.sh not found, skipping"
    fi
done

echo ""
echo "========================================="
echo "  All boards done!"
echo "========================================="
