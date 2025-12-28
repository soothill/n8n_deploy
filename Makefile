DOMAIN ?= n8n.soothill.com
EMAIL ?=
NGINX_CONF_DEST ?= /etc/nginx/conf.d/$(DOMAIN).conf
WEBROOT ?= /var/www/letsencrypt
ENV_FILE ?= deploy/podman/n8n.env

.PHONY: help env install-units nginx-conf cert deploy status logs

help:
	@echo "Targets:"
	@echo "  env             Create local $(ENV_FILE) from example (edit secrets afterward)"
	@echo "  install-units   Install quadlets to systemd and start n8n + Postgres"
	@echo "  nginx-conf      Install nginx vhost for $(DOMAIN) and reload nginx"
	@echo "  cert            Request Let's Encrypt cert (set EMAIL=<you@example.com>)"
	@echo "  deploy          Run env -> install-units -> nginx-conf"
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

nginx-conf:
	sudo install -d $(WEBROOT)
	sudo install -m 644 deploy/nginx/n8n.soothill.com.conf $(NGINX_CONF_DEST)
	sudo nginx -t
	sudo systemctl reload nginx

cert:
	@if [ -z "$(EMAIL)" ]; then echo "Set EMAIL=<you@example.com> to request a cert"; exit 1; fi
	WEBROOT=$(WEBROOT) DOMAIN=$(DOMAIN) EMAIL=$(EMAIL) ./scripts/request-cert.sh
	sudo nginx -t
	sudo systemctl reload nginx

deploy: env install-units nginx-conf

status:
	sudo systemctl status container-n8n.service container-n8n-postgres.service

logs:
	sudo journalctl -u container-n8n.service -f
