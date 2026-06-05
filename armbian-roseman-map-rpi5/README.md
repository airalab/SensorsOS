# SensorsOS — Raspberry Pi 5

Custom Armbian OS image for **Raspberry Pi 5** that automatically deploys
[RoSeMAN](https://github.com/falconexe/roseman) (NestJS blockchain indexer + MongoDB)
and [sensors.social](https://github.com/airalab/sensors.social) (decentralized sensor map)
on first boot.

## WiFi Setup

RPi 5 has built-in WiFi (BCM43455). After flashing the SD card, place a
`wpa_supplicant.conf` file on the **RPICFG** boot partition (FAT32, visible
on any computer when the SD card is inserted):

```ini
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="YOUR_WIFI_NAME"
    psk="YOUR_WIFI_PASSWORD"
}
```

Put the file in the **root** of the RPICFG partition — next to `config.txt`,
`cmdline.txt`, `vmlinuz`. On first boot `wifi-setup.service` imports the config
and connects automatically.

**No WiFi config = WiFi stays off.** Use Ethernet or add the file later.

Hidden networks: add `scan_ssid=1` inside `network={}`.
Open networks: use `key_mgmt=NONE` instead of `psk=`.

## Architecture

```
Port 80 (nginx on host)
  ├── /                  → /var/www/sensors-social/ (SPA)
  ├── /api/              → proxy → 127.0.0.1:3000 (Docker: roseman-rest-api)
  └── /metrics           → proxy → 127.0.0.1:3000 (Docker: roseman-rest-api)

Port 27017 (Docker: roseman-mongodb)
```

## Key Differences from Orange Pi 5 Build

| Aspect | Orange Pi 5 | Raspberry Pi 5 |
|--------|-------------|----------------|
| BOARD | `orangepi5` | `rpi4b` (covers all RPi models) |
| Kernel | Mainline 6.18.x | RPi fork `rpi-6.18.y` |
| SPI Flash | Needs erase script | Not applicable |
| WiFi | External dongle | Built-in BCM43455 |
| Hostname | `orangepi` | `raspberrypi` |

## Build Instructions

```bash
# 1. Clone Armbian build system (if not already)
git clone https://github.com/armbian/build.git ../armbian-build

# 2. Prepare Docker images
cd armbian-roseman-map-rpi5
./prepare-docker-images.sh

# 3. (Optional) Build sensors.social map
./build-map.sh

# 4. Build the Armbian image
./build.sh
```

### Flash to SD Card

```bash
xz -9 -T0 Armbian_*.img          # compress (optional)
xzcat Armbian_*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
# or use balenaEtcher (supports .xz directly)
```

## First Boot

1. Insert SD card into Raspberry Pi 5 and power on
2. `wifi-setup.service` imports WiFi config from `/boot/firmware/wpa_supplicant.conf`
3. Device connects to your WiFi network
4. SSH: `ssh root@raspberrypi` (password: `roseman`, forced change on first login)
5. `roseman-firstboot.service` loads Docker images → starts containers
6. Access: **Map** at `http://raspberrypi/`, **API** at `http://raspberrypi:3000/api`

## Default Credentials

- **SSH**: `root` / `roseman` (forced change on first login)
- **User**: `roseman` / `roseman` (in sudo group)
- **MongoDB**: auto-generated password (see `/opt/roseman/.mongo_password_generated`)

## Update RoSeMAN

```bash
sudo /opt/roseman/scripts/update.sh
```

## Reconfigure WiFi

```bash
# Edit WiFi config
sudo nano /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
sudo systemctl restart wpa_supplicant@wlan0
```

Or reset and use boot partition again:
```bash
sudo rm /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
# Place new wpa_supplicant.conf on RPICFG partition, then reboot
sudo reboot
```

## File Structure

```
armbian-roseman-map-rpi5/
├── build-config/
│   ├── config-rpi5-roseman.conf.sh   # Armbian board config (BOARD=rpi4b)
│   ├── customize-image.sh            # Chroot customization
│   ├── docker-compose.yml            # Docker services definition
│   ├── .env.example                  # RoSeMAN env template
│   ├── .env.polkadot.example         # Polkadot indexer env template
│   ├── firstboot.sh                  # First-boot service (Docker images)
│   ├── restore.sh                   # MongoDB restore script
│   ├── roseman-firstboot.service     # systemd unit (Docker services)
│   ├── update.sh                     # RoSeMAN update script
│   ├── wifi-setup.sh                 # WiFi config import from boot partition
│   ├── wifi-setup.service            # systemd unit (WiFi setup)
│   └── nginx-sensors-social.conf     # nginx config (map + API proxy)
├── overlay/
│   └── opt/roseman/
│       ├── .env.example, .env.polkadot.example
│       ├── Dockerfile, package.json, src/, ...
│       ├── docker-images/            # (populated by prepare-docker-images.sh)
│       └── dump/.gitkeep
│   └── var/www/sensors-social/       # (populated by build-map.sh)
├── build.sh                         # Main build script
├── build-map.sh                     # Build sensors.social SPA
├── prepare-docker-images.sh         # Pull & save Docker images
└── README.md
```