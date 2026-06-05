# =============================================================
# Armbian build config for Orange Pi 5 + RoSeMAN
# =============================================================
# Usage:
#   ./compile.sh orangepi5-roseman
# =============================================================

BOARD=orangepi5
BRANCH=current
RELEASE=noble
BUILD_MINIMAL=yes
BUILD_DESKTOP=no
KERNEL_CONFIGURE=no

# Use mainline kernel (6.18+) — required for MongoDB 8
# Vendor kernel 6.1.x lacks mmap flags needed by tcmalloc
