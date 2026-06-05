# SensorsOS — Orange Pi 5

Custom Armbian OS image for **Orange Pi 5** with
[RoSeMAN](https://github.com/falconexe/RoSeMAN) (NestJS blockchain indexer + MongoDB)
and [sensors.social](https://github.com/airalab/sensors.social) (decentralized sensor map)
pre-installed and configured for offline deployment.

## Image Details

| Parameter | Value |
|---|---|
| **Board** | Orange Pi 5 (`orangepi5`) |
| **OS** | Ubuntu 24.04 LTS (Noble), minimal |
| **Kernel** | Linux 6.18.x (mainline / current branch) |
| **Architecture** | aarch64 (arm64) |
| **Offline** | Docker images and SPA are baked into the image |

## Credentials

| | |
|---|---|
| **Hostname** | `orangepi` |
| **Root** | `root` / `roseman` — Armbian firstrun forces password change on first login |
| **User** | `roseman` / `roseman` — sudo group, docker group |
| **SSH** | Enabled, password authentication |
| **Serial console** | UART 1500000 baud |

### First login (headless)

```bash
ssh root@orangepi    # password: roseman, then forced change
# or
ssh roseman@orangepi # password: roseman, then sudo passwd root
```

## Docker

| Component | Version |
|---|---|
| **Docker Engine** | Installed from Ubuntu `docker.io` package |
| **Docker Compose** | v2.36.1 (binary, arm64) |

## Services

### RoSeMAN

| Container | Image | Purpose |
|---|---|---|
| `roseman-mongodb` | mongo:**8** | Database (mainline kernel supports MongoDB 8) |
| `roseman-mongo-restore` | mongo:8 | Init: restore from dump |
| `roseman-rest-api` | ghcr.io/falconexe/roseman:docker | REST API + Prometheus |
| `roseman-indexer-polkadot` | ghcr.io/falconexe/roseman:docker | Polkadot indexer |

### Sensor Map (sensors.social)

| | |
|---|---|
| **Server** | nginx on host, port 80 |
| **Files** | `/var/www/sensors-social/` (static SPA, ~37 MB) |
| **API** | nginx proxies `/api/` → `127.0.0.1:3000` (RoSeMAN REST API) |
| **URL** | `http://orangepi/` |

## Offline Support

Docker images are baked into the image as tar files (~1.2 GB total), loaded on
first boot via `roseman-firstboot.service`, then deleted to free SD card space.

The sensor map is a pre-built static SPA — no internet required.

## Flashing

```bash
xzcat Armbian-*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
# or use balenaEtcher (supports .xz directly)
```

## After First Boot

| | |
|---|---|
| **Map** | `http://<device-ip>/` |
| **REST API** | `http://<device-ip>:3000/api` |
| **SSH** | `ssh root@<device-ip>` (password: `roseman`, forced change) |
| **MongoDB password** | `/opt/roseman/.mongo_password_generated` |
| **Update RoSeMAN** | `sudo /opt/roseman/scripts/update.sh` |
| **First boot log** | `/var/log/roseman-firstboot.log` |

## Known Issues

- **SPI flash**: If Orange Pi 5 fails to boot from SD card, an old bootloader
  may be on SPI flash. Run `sudo /opt/roseman/scripts/erase-spi-flash.sh` to fix.
- **MongoDB 8**: Only works with mainline kernel (6.18+), not compatible with
  vendor kernel (6.1.x).
- **No WiFi**: Orange Pi 5 has no built-in WiFi — use Ethernet.

## Build from Source

See the [root README](../README.md) for prerequisites and full build instructions.

```bash
# In this directory:
./prepare-docker-images.sh   # pull Docker images (offline deployment)
./build-map.sh                # build sensors.social SPA
./build.sh                    # build Armbian image (30-60 min)
```

## Scripts in `/opt/roseman/scripts/`

| Script | Run | Purpose |
|---|---|---|
| `firstboot.sh` | Automatic (systemd) | Load Docker images → compose up → cleanup |
| `update.sh` | `sudo .../update.sh` | Online update: docker compose pull + up -d |
| `erase-spi-flash.sh` | `sudo .../erase-spi-flash.sh` | Erase SPI flash bootloader |
| `restore.sh` | Automatic (docker compose) | MongoDB restore from .bson |

## File Structure

```
armbian-roseman-map-opi5/
├── build-config/
│   ├── config-orangepi5-roseman.conf.sh   # Armbian board config (BOARD=orangepi5)
│   ├── customize-image.sh                 # Chroot customization
│   ├── docker-compose.yml                 # Docker services definition
│   ├── .env.example                       # RoSeMAN env template
│   ├── .env.polkadot.example              # Polkadot indexer env template
│   ├── firstboot.sh                       # First-boot service (Docker images)
│   ├── restore.sh                         # MongoDB restore script
│   ├── roseman-firstboot.service          # systemd unit (Docker services)
│   ├── update.sh                          # RoSeMAN update script
│   ├── erase-spi-flash.sh                 # SPI flash erase script
│   └── nginx-sensors-social.conf          # nginx config (map + API proxy)
├── overlay/                               # Staging: Docker images, SPA, RoSeMAN source
│   └── opt/roseman/
│       ├── docker-images/                 # (populated by prepare-docker-images.sh)
│       └── dump/.gitkeep
├── build.sh                               # Main build script
├── build-map.sh                            # Build sensors.social SPA
├── prepare-docker-images.sh                # Pull & save Docker images
└── README.md
```