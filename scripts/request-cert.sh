#!/usr/bin/env bash
# Copyright (c) 2025 Darren Soothill - darren [at] soothill dot com

set -euo pipefail

DOMAIN="${DOMAIN:-n8n.soothill.com}"
EMAIL="${EMAIL:-}"
WEBROOT="/srv/www/letsencrypt"
CERTBOT_IMAGE="${CERTBOT_IMAGE:-docker.io/certbot/certbot:latest}"

if [[ -z "${EMAIL}" ]]; then
  echo "Set EMAIL=<your email> to request the certificate."
  exit 1
fi

sudo install -d -m 755 "${WEBROOT}" /etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt

sudo podman run --rm \
  -v "/etc/letsencrypt:/etc/letsencrypt:Z" \
  -v "/var/lib/letsencrypt:/var/lib/letsencrypt:Z" \
  -v "/var/log/letsencrypt:/var/log/letsencrypt:Z" \
  -v "${WEBROOT}:${WEBROOT}:Z" \
  "${CERTBOT_IMAGE}" certonly \
  --webroot -w "${WEBROOT}" \
  -d "${DOMAIN}" \
  -n --agree-tos -m "${EMAIL}"

echo "Certificate request complete. Reload nginx to pick up new certs."
