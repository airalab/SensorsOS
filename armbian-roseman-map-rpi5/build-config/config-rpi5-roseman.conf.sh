# =============================================================
# Armbian build config for Raspberry Pi 5 + RoSeMAN
# =============================================================
# Usage:
#   ./compile.sh rpi5-roseman
# =============================================================

BOARD=rpi4b
BRANCH=current
RELEASE=noble
BUILD_MINIMAL=yes
BUILD_DESKTOP=no
KERNEL_CONFIGURE=no

# Raspberry Pi kernel fork (rpi-6.18.y) supports BCM2712 (RPi 5)
# This board config covers ALL RPi models: 3B+, 4, 5, 400, CM4, CM5
