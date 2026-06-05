# SensorsOS

Custom Armbian OS images for **Orange Pi 5** and **Raspberry Pi 5** with
[RoSeMAN](https://github.com/falconexe/RoSeMAN) (blockchain indexer + MongoDB)
and [sensors.social](https://github.com/airalab/sensors.social) (sensor map)
pre-installed and configured for offline deployment.

## Features

- **Offline-first**: Docker images and SPA are baked into the image — no internet needed after flashing
- **Auto-start**: All services start on first boot via systemd
- **WiFi (RPi 5)**: Built-in BCM43455, configure via `wpa_supplicant.conf` on boot partition
- **Sensor map**: nginx serves sensors.social on port 80, proxies `/api/` to RoSeMAN

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| **Host OS** | Ubuntu 22.04+ (x86_64) | Armbian build requires Linux |
| **Docker** | 20+ | `curl -fsSL https://get.docker.com \| sh` |
| **QEMU/binfmt** | for arm64 emulation | `docker run --privileged --rm tonistiigi/binfmt --install all` |
| **Node.js** | 20+ | For building sensors.social SPA |
| **Git** | any | System package |
| **xz** | any | System package |
| **~25 GB free disk** | for build cache + output | Armbian build is disk-hungry |
| **~2 GB RAM** | minimum | 4+ GB recommended |

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/falconexe/SensorsOS.git
cd SensorsOS

# 2. Setup QEMU for arm64 cross-build
docker run --privileged --rm tonistiigi/binfmt --install all

# 3. Sync RoSeMAN source (REQUIRED — not tracked in git)
./sync-roseman.sh

# 4. Build (choose your board)
cd armbian-roseman-map-opi5     # or armbian-roseman-map-rpi5
./prepare-docker-images.sh      # pull Docker images (offline deployment)
./build-map.sh                  # build sensors.social SPA
./build.sh                       # build Armbian image (clones Armbian repo + builds, 30-60 min)

# 5. Flash
xzcat Armbian-*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
# or use balenaEtcher (supports .xz directly)
```

## Board-Specific Setup

### Orange Pi 5

- No WiFi on board — use Ethernet
- If boot fails from SD card, run `sudo /opt/roseman/scripts/erase-spi-flash.sh`

### Raspberry Pi 5

- Built-in WiFi (BCM43455) — place `wpa_supplicant.conf` on the **RPICFG** boot partition:

```ini
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="YOUR_WIFI_NAME"
    psk="YOUR_WIFI_PASSWORD"
}
```

- Hidden networks: add `scan_ssid=1` inside `network={}`
- Open networks: use `key_mgmt=NONE` instead of `psk=`
- No config file = WiFi stays off, use Ethernet

## After First Boot

| | |
|---|---|
| **Map** | `http://<device-ip>/` |
| **REST API** | `http://<device-ip>:3000/api` |
| **SSH** | `ssh root@<device-ip>` (password: `roseman`, forced change) |
| **User** | `roseman` / `roseman` (sudo group) |
| **MongoDB password** | `/opt/roseman/.mongo_password_generated` |
| **Update RoSeMAN** | `sudo /opt/roseman/scripts/update.sh` |

## Repository Structure

```
SensorsOS/
├── armbian-roseman-map-opi5/          # Orange Pi 5 image
│   ├── build-config/                  # Board config, scripts, .env, systemd
│   ├── overlay/                       # Staging: Docker images, SPA, source
│   ├── build.sh                       # Assembles overlay + runs Armbian build
│   ├── prepare-docker-images.sh       # Pulls Docker images for arm64
│   ├── build-map.sh                   # Builds sensors.social SPA
│   └── README.md
├── armbian-roseman-map-rpi5/          # Raspberry Pi 5 image (same structure)
│   └── ...
├── armbian-build/                     # Armbian build system (git clone, not tracked)
├── sync-roseman.sh                   # Syncs RoSeMAN source from GitHub
├── prepare-docker-images.sh           # Convenience: runs both boards
├── sensors-social-map/build-map.sh    # Convenience: runs both boards
├── LICENSE                            # MIT
└── README.md
```

## Updating RoSeMAN

When the [RoSeMAN](https://github.com/falconexe/RoSeMAN) Docker image is updated on ghcr.io:

```bash
cd SensorsOS

# Sync source code (REQUIRED — not in git)
./sync-roseman.sh

# For each board:
cd armbian-roseman-map-opi5     # or armbian-roseman-map-rpi5
rm -f overlay/opt/roseman/docker-images/*.tar
./prepare-docker-images.sh      # pull new images
./build.sh                      # rebuild Armbian image
```

## License

[MIT](LICENSE) for scripts and configs in this repository.
Third-party software (Armbian, RoSeMAN, sensors.social, MongoDB) is subject to their respective licenses.