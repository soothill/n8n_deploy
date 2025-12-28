# Copyright (c) 2025 Darren Soothill - darren [at] soothill dot com

DOMAIN ?= n8n.soothill.com
EMAIL ?=
NGINX_CONF_DEST ?= /etc/nginx/conf.d/$(DOMAIN).conf
WEBROOT ?= /var/www/letsencrypt
ENV_FILE ?= deploy/podman/n8n.env

.PHONY: help env install-units prepare-webroot nginx-http nginx-https cert deploy status logs secure check-dns remove status-podman

help:
	@echo "Targets:"
	@echo "  env             Create local $(ENV_FILE) from example (edit secrets afterward)"
	@echo "  install-units   Install quadlets to systemd and start n8n + Postgres"
	@echo "  prepare-webroot Ensure ACME webroot exists, perms are open, and SELinux allows nginx network"
	@echo "  nginx-http      Install HTTP-only nginx vhost (bootstraps cert issuance)"
	@echo "  nginx-https     Install HTTPS nginx vhost (requires cert already present)"
	@echo "  cert            Request Let's Encrypt cert (set EMAIL=<you@example.com>)"
	@echo "  deploy          Run env -> install-units -> nginx-http"
	@echo "  secure          Run cert -> nginx-https (after DNS/ports are ready)"
	@echo "  check-dns       Validate that $(DOMAIN) resolves"
	@echo "  remove          Stop/disable services and remove quadlet/nginx configs (data volumes stay)"
	@echo "  status          Show systemd status for n8n services"
	@echo "  status-podman   Show podman container status for n8n services"
	@echo "  logs            Tail n8n service logs"

env:
	@if [ ! -f $(ENV_FILE) ]; then \
		cp deploy/podman/n8n.env.example $(ENV_FILE); \
		echo "Created $(ENV_FILE). Edit secrets before deploying."; \
	else \
		echo "$(ENV_FILE) already exists; leaving untouched."; \
	fi

install-units: env
	N8N_ENV_SRC="$(shell realpath $(ENV_FILE))" ./scripts/apply-podman-units.sh

prepare-webroot:
	sudo install -d -m 755 $(WEBROOT)/.well-known/acme-challenge
	sudo chmod -R a+rX $(WEBROOT)
	if command -v restorecon >/dev/null 2>&1; then sudo restorecon -Rv $(WEBROOT) || true; elif command -v chcon >/dev/null 2>&1; then sudo chcon -Rt httpd_sys_content_t $(WEBROOT) || true; fi
	if command -v setsebool >/dev/null 2>&1; then sudo setsebool -P httpd_can_network_connect 1 || true; fi

nginx-http: prepare-webroot
	sudo install -d $(WEBROOT)
	sudo install -m 644 deploy/nginx/n8n.soothill.com.http.conf $(NGINX_CONF_DEST)
	sudo nginx -t
	sudo systemctl restart nginx || true
	sudo systemctl is-active nginx >/dev/null || sudo systemctl start nginx
	sudo systemctl status nginx --no-pager

nginx-https:
	@if [ ! -f /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem ]; then echo "Missing cert for $(DOMAIN). Run: make cert EMAIL=you@example.com"; exit 1; fi
	sudo install -m 644 deploy/nginx/n8n.soothill.com.conf $(NGINX_CONF_DEST)
	sudo nginx -t
	sudo systemctl restart nginx || true
	sudo systemctl is-active nginx >/dev/null || sudo systemctl start nginx
	sudo systemctl status nginx --no-pager

cert:
	@if [ -z "$(EMAIL)" ]; then echo "Set EMAIL=<you@example.com> to request a cert"; exit 1; fi
	@if [ ! -f $(NGINX_CONF_DEST) ]; then echo "Install HTTP vhost first: make nginx-http"; exit 1; fi
	$(MAKE) prepare-webroot
	$(MAKE) check-dns
	WEBROOT=$(WEBROOT) DOMAIN=$(DOMAIN) EMAIL=$(EMAIL) ./scripts/request-cert.sh
	sudo nginx -t
	sudo systemctl restart nginx || true
	sudo systemctl is-active nginx >/dev/null || sudo systemctl start nginx
	sudo systemctl status nginx --no-pager

deploy: env install-units nginx-http

secure: cert nginx-https

check-dns:
	@if getent ahosts $(DOMAIN) >/dev/null 2>&1; then \
		echo "DNS OK for $(DOMAIN)"; \
	else \
		echo "DNS lookup failed for $(DOMAIN). Verify your A/AAAA records."; \
		exit 1; \
	fi

remove:
	@echo "Stopping and disabling systemd units..."
	sudo systemctl disable --now container-n8n.service container-n8n-postgres.service podman-network-n8n.service || true
	@echo "Removing quadlet files..."
	sudo rm -f /etc/containers/systemd/n8n.container /etc/containers/systemd/n8n-postgres.container /etc/containers/systemd/n8n.network
	sudo systemctl daemon-reload
	@echo "Removing nginx vhost if present..."
	@if [ -f $(NGINX_CONF_DEST) ]; then sudo rm -f $(NGINX_CONF_DEST); fi
	@if command -v nginx >/dev/null 2>&1; then sudo nginx -t && sudo systemctl reload nginx; fi
	@echo "Removal complete. Data volumes and certificates remain; prune manually if desired."

status:
	sudo systemctl status container-n8n.service container-n8n-postgres.service

logs:
	sudo journalctl -u container-n8n.service -f

status-podman:
	sudo podman ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}'
