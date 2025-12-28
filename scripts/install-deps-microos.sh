#!/usr/bin/env bash
# Copyright (c) 2025 Darren Soothill - darren [at] soothill dot com

set -euo pipefail

PACKAGES="make podman podman-quadlet nginx certbot"
REBOOT="${REBOOT:-false}"

if ! command -v transactional-update >/dev/null 2>&1; then
  echo "transactional-update not found. This helper is intended for openSUSE MicroOS."
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required to run transactional-update."
  exit 1
fi

sudo -v

echo "Installing packages: ${PACKAGES}"
sudo transactional-update pkg install -y ${PACKAGES}

if [ "${REBOOT}" = "true" ]; then
  echo "Rebooting to apply transactional changes..."
  sudo reboot
else
  echo "Transactional install queued. Reboot the host to activate the new packages."
fi
