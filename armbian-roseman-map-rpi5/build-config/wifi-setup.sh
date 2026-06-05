#!/bin/bash
# =============================================================
# WiFi Setup for Raspberry Pi 5
#
# On boot, imports wpa_supplicant.conf from the boot partition
# (visible as RPICFG when SD card is inserted into a computer).
#
# If the file exists → copy to /etc/wpa_supplicant/, start client mode.
# If not → WiFi stays down (use Ethernet or add the config file).
# =============================================================
set -euo pipefail

WPA_CONF="/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"
BOOT_CONF="/boot/firmware/wpa_supplicant.conf"
LOG="/var/log/wifi-setup.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

# ── Main ───────────────────────────────────────────────────────
log "=== WiFi Setup Starting ==="

# Make sure wlan0 exists
if ! ip link show wlan0 &>/dev/null; then
	log "wlan0 not found, skipping WiFi setup."
	exit 0
fi

# Import wpa_supplicant.conf from boot partition if present
if [[ -f "${BOOT_CONF}" ]]; then
	log "Found wpa_supplicant.conf on boot partition. Importing..."
	cp "${BOOT_CONF}" "${WPA_CONF}"
	chmod 600 "${WPA_CONF}"
	rm -f "${BOOT_CONF}"
	log "WiFi config imported. Removed from boot partition."
else
	log "No wpa_supplicant.conf on boot partition."
	if [[ -f "${WPA_CONF}" ]] && grep -q "^network=" "${WPA_CONF}" 2>/dev/null; then
		log "WiFi config already exists in /etc/wpa_supplicant/."
	else
		log "No WiFi config found. WiFi will not connect."
		log "To configure WiFi, create wpa_supplicant.conf on the RPICFG partition."
	fi
fi

# Start wpa_supplicant if config exists
if [[ -f "${WPA_CONF}" ]] && grep -q "^network=" "${WPA_CONF}" 2>/dev/null; then
	log "Starting wpa_supplicant..."
	systemctl start wpa_supplicant@wlan0 2>/dev/null || true
else
	log "No WiFi networks configured."
fi

log "=== WiFi Setup Complete ==="
