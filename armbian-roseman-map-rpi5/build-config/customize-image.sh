#!/bin/bash
# =============================================================
# Armbian customize-image.sh for Raspberry Pi 5 + RoSeMAN
#
# Runs inside chroot during image build.
# Host overlay directory is mounted at /tmp/overlay
# =============================================================

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

Main() {
	InstallDocker
	InstallNginx
	InstallWiFiSetup
	InstallDefaultUser
	InstallRoSeMAN
	InstallSensorsSocial
	InstallFirstbootService
	InstallUpdateScript
} # Main

InstallDocker() {
	# Update package lists
	apt-get update || apt-get update || true

	# Install Docker Engine from Ubuntu repos
	# Retry in case of transient network issues
	for i in 1 2 3; do
		if apt-get install -y docker.io; then
			break
		fi
		echo "Retrying docker.io install (attempt $i)..."
		apt-get update || true
		sleep 5
	done

	# Install docker compose plugin — download binary for arm64
	COMPOSE_VERSION="2.36.1"
	COMPOSE_URL="https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-aarch64"
	mkdir -p /usr/local/lib/docker/cli-plugins
	echo "Downloading docker compose v${COMPOSE_VERSION}..."
	for i in 1 2 3; do
		if curl -fSL -o /usr/local/lib/docker/cli-plugins/docker-compose "${COMPOSE_URL}"; then
			break
		fi
		echo "Retrying docker compose download (attempt $i)..."
		sleep 5
	done
	chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

	# Enable Docker on boot
	systemctl enable docker

	# Add armbian user to docker group (created by docker.io package)
	if getent group docker &>/dev/null; then
		usermod -aG docker armbian 2>/dev/null || true
	fi
}

InstallNginx() {
	# Install nginx
	apt-get install -y nginx

	# Remove default site
	rm -f /etc/nginx/sites-enabled/default

	# Copy sensors-social nginx config
	cp /tmp/overlay/etc/nginx/sites-available/sensors-social /etc/nginx/sites-available/sensors-social
	ln -sf /etc/nginx/sites-available/sensors-social /etc/nginx/sites-enabled/sensors-social

	# Enable nginx on boot
	systemctl enable nginx
}

InstallWiFiSetup() {
	# Install WiFi packages
	apt-get install -y iw wpasupplicant

	# Create empty wpa_supplicant config (populated via wpa_supplicant.conf on boot partition)
	mkdir -p /etc/wpa_supplicant
	cat > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf << 'EOF'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US
EOF
	chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

	# Copy wifi-setup script
	cp /tmp/overlay/opt/roseman/scripts/wifi-setup.sh /opt/roseman/scripts/wifi-setup.sh
	chmod +x /opt/roseman/scripts/wifi-setup.sh

	# Copy systemd service
	cp /tmp/overlay/etc/systemd/system/wifi-setup.service /etc/systemd/system/wifi-setup.service

	# Enable wifi-setup service (runs on every boot to import config)
	systemctl enable wifi-setup.service

	# Configure systemd-networkd for wlan0 (DHCP client)
	mkdir -p /etc/systemd/network
	cat > /etc/systemd/network/10-wlan0-dhcp.network << 'EOF'
[Match]
Name=wlan0

[Network]
DHCP=yes
EOF

	# Enable systemd-networkd
	systemctl enable systemd-networkd
}

InstallDefaultUser() {
	local USERNAME="roseman"
	local PASSWORD="roseman"

	# Create roseman user (system user for service management, no home dir)
	useradd -r -s /bin/bash "${USERNAME}"
	echo "${USERNAME}:${PASSWORD}" | chpasswd
	usermod -aG sudo "${USERNAME}"

	# Add to docker group (may not exist yet if Docker install failed)
	if getent group docker &>/dev/null; then
		usermod -aG docker "${USERNAME}"
	fi

	# Pre-set root password for headless SSH access
	# Armbian firstrun will force a password change on first login
	echo "root:roseman" | chpasswd

	# Keep Armbian first-run setup — it will force password change on first login
	# (don't remove /root/.not_logged_in_yet)

	# Disable Armbian auto-login as root (show normal login prompt)
	rm -f /etc/systemd/system/getty@tty*.service.d/override.conf
	rm -f /etc/systemd/system/serial-getty@tty*.service.d/override.conf
	systemctl reenable getty@tty1.service 2>/dev/null || true

	# Ensure SSH host keys exist and service is enabled
	ssh-keygen -A
	systemctl enable ssh

	# Allow SSH password authentication
	# First remove any existing PasswordAuthentication lines, then add ours
	sed -i '/^#*PasswordAuthentication/d' /etc/ssh/sshd_config
	echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

	# Set hostname
	echo "raspberrypi" > /etc/hostname
	sed -i "s/localhost/raspberrypi/" /etc/hosts
}

InstallRoSeMAN() {
	# Copy entire project from overlay (including hidden dotfiles)
	mkdir -p /opt/roseman
	shopt -s dotglob
	cp -r /tmp/overlay/opt/roseman/* /opt/roseman/
	shopt -u dotglob

	# Generate .env with random MongoDB password
	if [[ ! -f /opt/roseman/.env ]]; then
		MONGO_PASSWORD=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 32)
		sed \
			-e "s|secret|${MONGO_PASSWORD}|g" \
			-e "s|^MONGO_VERSION=.*|MONGO_VERSION=8|" \
			/tmp/overlay/opt/roseman/.env.example > /opt/roseman/.env

		# Store generated password for display on first login
		echo "${MONGO_PASSWORD}" > /opt/roseman/.mongo_password_generated
		chmod 600 /opt/roseman/.mongo_password_generated
	fi

	# Copy .env.polkadot
	if [[ ! -f /opt/roseman/.env.polkadot ]]; then
		cp /opt/roseman/.env.polkadot.example /opt/roseman/.env.polkadot
	fi

	# Ensure all scripts are executable (cp -r may reset permissions)
	chmod +x /opt/roseman/scripts/*.sh /opt/roseman/scripts/*.py 2>/dev/null || true
}

InstallSensorsSocial() {
	# Copy built SPA files from overlay
	if [[ -d /tmp/overlay/var/www/sensors-social ]]; then
		mkdir -p /var/www/sensors-social
		cp -r /tmp/overlay/var/www/sensors-social/* /var/www/sensors-social/
		chown -R www-data:www-data /var/www/sensors-social
	fi
}

InstallFirstbootService() {
	# Copy systemd unit
	cp /tmp/overlay/etc/systemd/system/roseman-firstboot.service /etc/systemd/system/roseman-firstboot.service

	# Copy firstboot script
	cp /tmp/overlay/opt/roseman/scripts/firstboot.sh /opt/roseman/scripts/firstboot.sh
	chmod +x /opt/roseman/scripts/firstboot.sh

	# Enable the service — runs once on first boot
	systemctl enable roseman-firstboot.service
}

InstallUpdateScript() {
	cp /tmp/overlay/opt/roseman/scripts/update.sh /opt/roseman/scripts/update.sh
	chmod +x /opt/roseman/scripts/update.sh
	# NOTE: No erase-spi-flash.sh — RPi 5 does not have conflicting SPI U-Boot
}

Main "$@"
