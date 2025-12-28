#!/usr/bin/env bash
# Copyright (c) 2025 Darren Soothill - darren [at] soothill dot com

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${REPO_ROOT}/deploy/podman"
DEST="/etc/containers/systemd"
ENV_DEST="/etc/n8n/n8n.env"
ENV_SRC="${N8N_ENV_SRC:-${SRC}/n8n.env}"

if ! command -v podman >/dev/null 2>&1; then
  echo "Podman is required. Install podman and retry."
  exit 1
fi

GEN_BIN="${PODMAN_SYSTEM_GENERATOR:-}"
if [ -z "${GEN_BIN}" ]; then
  GEN_BIN="$(command -v podman-system-generator || true)"
fi
if [ -z "${GEN_BIN}" ]; then
  for candidate in /usr/lib/systemd/system-generators/podman-system-generator /lib/systemd/system-generators/podman-system-generator; do
    if [ -x "${candidate}" ]; then
      GEN_BIN="${candidate}"
      break
    fi
  done
fi
if [ -z "${GEN_BIN}" ]; then
  echo "Podman quadlet generator not found. Install podman-quadlet (e.g., sudo transactional-update pkg install podman-quadlet) and reboot."
  exit 1
fi

echo "Applying quadlet definitions from ${SRC}..."
sudo install -d "${DEST}" /etc/n8n
sudo install -m 644 "${SRC}/n8n-postgres.container" "${DEST}/n8n-postgres.container"
sudo install -m 644 "${SRC}/n8n.container" "${DEST}/n8n.container"

if [ ! -f "${ENV_DEST}" ]; then
  if [ ! -f "${ENV_SRC}" ]; then
    echo "Environment source ${ENV_SRC} not found. Create it (e.g., copy n8n.env.example) and set secrets."
    exit 1
  fi
  sudo install -m 640 "${ENV_SRC}" "${ENV_DEST}"
  echo "Created ${ENV_DEST} from ${ENV_SRC}. Update secrets before starting services."
else
  echo "Environment file ${ENV_DEST} already exists; leaving untouched."
fi

echo "Ensuring Podman network 'n8n' exists..."
sudo podman network inspect n8n >/dev/null 2>&1 || sudo podman network create --driver bridge --subnet 10.89.0.0/24 --gateway 10.89.0.1 n8n

echo "Regenerating systemd units via podman-system-generator..."
GEN_LOG="$(mktemp /tmp/podman-quadlet-gen.XXXX.log)"
if ! sudo "${GEN_BIN}" &> "${GEN_LOG}"; then
  echo "podman-system-generator failed. See log: ${GEN_LOG}"
  cat "${GEN_LOG}"
  exit 1
fi
sudo systemctl daemon-reload

if [ ! -f /run/systemd/generator/container-n8n.service ]; then
  echo "Generated unit /run/systemd/generator/container-n8n.service is missing."
  echo "Check podman-quadlet installation and version, then rerun this script."
  exit 1
fi

sudo systemctl enable --now container-n8n-postgres.service container-n8n.service
sudo systemctl status container-n8n.service --no-pager
