#!/bin/bash
# =============================================================
# Erase SPI flash on Orange Pi 5
#
# This removes any old U-Boot bootloader from SPI flash,
# forcing the board to boot from SD card instead.
#
# Run this ONLY if the board fails to boot from SD card
# (e.g. stuck at "Jumping to U-Boot" with no further output).
#
# WARNING: This will erase the SPI flash bootloader.
# After this, the board will ONLY boot from SD card or eMMC,
# until a new bootloader is written to SPI flash.
#
# Usage:
#   sudo /opt/roseman/scripts/erase-spi-flash.sh
# =============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# Must be root
if [[ $EUID -ne 0 ]]; then
    error "Run this script as root: sudo $0"
fi

# Check for SPI flash device
if ! ls /dev/mtd* &>/dev/null; then
    error "No MTD devices found. SPI flash may not be available on this board."
fi

# List available MTD devices
info "Available MTD devices:"
cat /proc/mtd 2>/dev/null || ls -la /dev/mtd*

echo ""
warn "This will erase the SPI flash bootloader."
warn "After this, the board will ONLY boot from SD card or eMMC."
echo ""
read -p "Are you sure? Type 'yes' to continue: " CONFIRM

if [[ "${CONFIRM}" != "yes" ]]; then
    info "Cancelled."
    exit 0
fi

# Find SPI flash (usually mtd0)
MTD_DEVICE=""
if [[ -e /dev/mtd0 ]]; then
    MTD_DEVICE="/dev/mtd0"
elif [[ -e /dev/mtdblock0 ]]; then
    MTD_DEVICE="/dev/mtdblock0"
else
    error "Cannot find SPI flash device."
fi

info "Erasing SPI flash at ${MTD_DEVICE}..."
dd if=/dev/zero of="${MTD_DEVICE}" bs=1M count=1 status=progress

info "SPI flash erased successfully!"
echo ""
info "========================================="
info "  Power off the board, then power on."
info "  It should now boot from SD card."
info "========================================="
