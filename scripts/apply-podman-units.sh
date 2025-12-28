#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${REPO_ROOT}/deploy/podman"
DEST="/etc/containers/systemd"
ENV_DEST="/etc/n8n/n8n.env"
ENV_SRC="${N8N_ENV_SRC:-${SRC}/n8n.env}"

echo "Applying quadlet definitions from ${SRC}..."
sudo install -d "${DEST}" /etc/n8n
sudo install -m 644 "${SRC}/n8n.network" "${DEST}/n8n.network"
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

sudo systemctl daemon-reload
sudo systemctl enable --now podman-network-n8n.service container-n8n-postgres.service container-n8n.service
sudo systemctl status container-n8n.service --no-pager
