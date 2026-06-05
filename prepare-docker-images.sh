#!/bin/bash
# =============================================================
# prepare-docker-images.sh
#
# Convenience wrapper — pulls Docker images for all boards.
# For individual boards, run the script in each subdirectory:
#   cd armbian-roseman-map-opi5 && ./prepare-docker-images.sh
#   cd armbian-roseman-map-rpi5 && ./prepare-docker-images.sh
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================="
echo "  Pulling Docker images for all boards"
echo "================================="

for BOARD in armbian-roseman-map-opi5 armbian-roseman-map-rpi5; do
    BOARD_DIR="${SCRIPT_DIR}/${BOARD}"
    if [[ -x "${BOARD_DIR}/prepare-docker-images.sh" ]]; then
        echo ""
        echo ">>> ${BOARD}"
        echo ""
        (cd "${BOARD_DIR}" && ./prepare-docker-images.sh)
    else
        echo "WARNING: ${BOARD_DIR}/prepare-docker-images.sh not found, skipping"
    fi
done

echo ""
echo "========================================="
echo "  All boards done!"
echo "========================================="
