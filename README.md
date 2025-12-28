# n8n_deploy

Podman + nginx deployment assets for running n8n on openSUSE MicroOS.

## What this repo contains
- Quadlet definitions for Podman-managed services: `deploy/podman/n8n.container`, `deploy/podman/n8n-postgres.container`, and `deploy/podman/n8n.network`.
- Environment template: `deploy/podman/n8n.env.example` (copy to `deploy/podman/n8n.env`, which is gitignored, then pushed to `/etc/n8n/n8n.env`).
- Nginx virtual host for `n8n.soothill.com`: `deploy/nginx/n8n.soothill.com.conf`.
- Helper scripts to install units and request TLS certs in `scripts/`.
- Makefile targets to orchestrate the deployment.

## Prerequisites
- openSUSE MicroOS host with Podman and systemd quadlet support.
- Existing nginx installation (listening on :80/:443) and DNS A/AAAA pointing `n8n.soothill.com` to this host.
- Ports 80 and 443 open to the internet for ACME HTTP-01.

## Configuration
- Create a working env file (gitignored) from the example and set secrets:
  ```bash
  make env
  nano deploy/podman/n8n.env
  ```
  The deploy script will copy this to `/etc/n8n/n8n.env`.
- Required edits: set strong values for `N8N_ENCRYPTION_KEY`, `POSTGRES_PASSWORD`, and optional `BASIC_AUTH_*`.

## Make targets (run from repo root)
- `make deploy` — creates `deploy/podman/n8n.env` (if missing), installs quadlets, and installs nginx vhost.
- `make cert EMAIL=you@example.com` — requests a Let’s Encrypt cert via webroot; reloads nginx.
- `make status` — shows systemd status for n8n and Postgres.
- `make logs` — tails n8n service logs.

## Manual equivalents (if not using make)
```bash
N8N_ENV_SRC="$(pwd)/deploy/podman/n8n.env" ./scripts/apply-podman-units.sh
sudo install -d /var/www/letsencrypt
sudo install -m 644 deploy/nginx/n8n.soothill.com.conf /etc/nginx/conf.d/n8n.soothill.com.conf
sudo nginx -t && sudo systemctl reload nginx
EMAIL=you@example.com ./scripts/request-cert.sh && sudo systemctl reload nginx
```

## Managing the stack
- Check status: `sudo systemctl status container-n8n.service container-n8n-postgres.service`
- View logs: `sudo journalctl -u container-n8n.service -f`
- Auto-updates: Podman is labeled for `io.containers.autoupdate=registry` if enabled on the host.
