# Copyright (c) 2025 Darren Soothill - darren [at] soothill dot com

DOMAIN ?= n8n.soothill.com
EMAIL ?=
NGINX_CONF_DEST ?= /etc/nginx/conf.d/$(DOMAIN).conf
WEBROOT ?= /var/www/letsencrypt
ENV_FILE ?= deploy/podman/n8n.env

.PHONY: help env install-units nginx-http nginx-https cert deploy status logs secure check-dns

help:
	@echo "Targets:"
	@echo "  env             Create local $(ENV_FILE) from example (edit secrets afterward)"
	@echo "  install-units   Install quadlets to systemd and start n8n + Postgres"
	@echo "  nginx-http      Install HTTP-only nginx vhost (bootstraps cert issuance)"
	@echo "  nginx-https     Install HTTPS nginx vhost (requires cert already present)"
	@echo "  cert            Request Let's Encrypt cert (set EMAIL=<you@example.com>)"
	@echo "  deploy          Run env -> install-units -> nginx-http"
	@echo "  secure          Run cert -> nginx-https (after DNS/ports are ready)"
	@echo "  check-dns       Validate that $(DOMAIN) resolves"
	@echo "  status          Show systemd status for n8n services"
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

nginx-http:
	sudo install -d $(WEBROOT)
	sudo install -m 644 deploy/nginx/n8n.soothill.com.http.conf $(NGINX_CONF_DEST)
	sudo nginx -t
	sudo systemctl reload nginx

nginx-https:
	@if [ ! -f /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem ]; then echo "Missing cert for $(DOMAIN). Run: make cert EMAIL=you@example.com"; exit 1; fi
	sudo install -m 644 deploy/nginx/n8n.soothill.com.conf $(NGINX_CONF_DEST)
	sudo nginx -t
	sudo systemctl reload nginx

cert:
	@if [ -z "$(EMAIL)" ]; then echo "Set EMAIL=<you@example.com> to request a cert"; exit 1; fi
	@if [ ! -f $(NGINX_CONF_DEST) ]; then echo "Install HTTP vhost first: make nginx-http"; exit 1; fi
	$(MAKE) check-dns
	WEBROOT=$(WEBROOT) DOMAIN=$(DOMAIN) EMAIL=$(EMAIL) ./scripts/request-cert.sh
	sudo nginx -t
	sudo systemctl reload nginx

deploy: env install-units nginx-http

secure: cert nginx-https

check-dns:
	@if getent ahosts $(DOMAIN) >/dev/null 2>&1; then \
		echo "DNS OK for $(DOMAIN)"; \
	else \
		echo "DNS lookup failed for $(DOMAIN). Verify your A/AAAA records."; \
		exit 1; \
	fi

status:
	sudo systemctl status container-n8n.service container-n8n-postgres.service

logs:
	sudo journalctl -u container-n8n.service -f
