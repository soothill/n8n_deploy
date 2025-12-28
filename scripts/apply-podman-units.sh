#!/usr/bin/env bash
# Copyright (c) 2025 Darren Soothill - darren [at] soothill dot com

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${REPO_ROOT}/deploy/podman"
DEST="/etc/containers/systemd"
ENV_DEST="/etc/n8n/n8n.env"
ENV_SRC="${N8N_ENV_SRC:-${SRC}/n8n.env}"
SUDO="sudo"
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
fi
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/0}"

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
$SUDO install -d "${DEST}" /etc/n8n
$SUDO install -m 644 "${SRC}/n8n-postgres.container" "${DEST}/n8n-postgres.container"
$SUDO install -m 644 "${SRC}/n8n.container" "${DEST}/n8n.container"

if [ ! -f "${ENV_DEST}" ]; then
  if [ ! -f "${ENV_SRC}" ]; then
    echo "Environment source ${ENV_SRC} not found. Create it (e.g., copy n8n.env.example) and set secrets."
    exit 1
  fi
  $SUDO install -m 640 "${ENV_SRC}" "${ENV_DEST}"
  echo "Created ${ENV_DEST} from ${ENV_SRC}. Update secrets before starting services."
else
  echo "Environment file ${ENV_DEST} already exists; leaving untouched."
fi

echo "Ensuring Podman network 'n8n' exists..."
$SUDO podman network inspect n8n >/dev/null 2>&1 || $SUDO podman network create --driver bridge --subnet 10.89.0.0/24 --gateway 10.89.0.1 n8n

echo "Regenerating systemd units via podman-system-generator..."
GEN_LOG="$(mktemp /tmp/podman-quadlet-gen.XXXX.log)"
OUT_EARLY="/run/systemd/generator.early"
OUT_MAIN="/run/systemd/generator"
OUT_LATE="/run/systemd/generator.late"
$SUDO install -d "${OUT_EARLY}" "${OUT_MAIN}" "${OUT_LATE}"
set +e
$SUDO "${GEN_BIN}" "${OUT_MAIN}" "${OUT_LATE}" "${OUT_EARLY}" &> "${GEN_LOG}"
GEN_RC=$?
set -e
if [ "${GEN_RC}" -ne 0 ]; then
  echo "podman-system-generator exited with ${GEN_RC}. Continuing. Log: ${GEN_LOG}"
fi
$SUDO systemctl daemon-reload

GEN_SERVICE="$(find /run/systemd -maxdepth 4 -name 'container-n8n.service' -print -quit)"
GEN_PG_SERVICE="$(find /run/systemd -maxdepth 4 -name 'container-n8n-postgres.service' -print -quit)"

if [ -z "${GEN_SERVICE}" ] || [ -z "${GEN_PG_SERVICE}" ]; then
  echo "Generated quadlet services are missing."
  echo "Checked locations under /run/systemd; found:"
  find /run/systemd -maxdepth 3 -name 'container-*.service' -print
  echo "Inputs in /etc/containers/systemd:"
  ls -l /etc/containers/systemd
  echo "Generator log (exit ${GEN_RC}): ${GEN_LOG}"
  cat "${GEN_LOG}"
  exit 1
fi

$SUDO systemctl enable --now container-n8n-postgres.service container-n8n.service
$SUDO systemctl status container-n8n.service --no-pager
