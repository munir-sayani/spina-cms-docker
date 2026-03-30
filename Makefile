.PHONY: help install up down build logs bundle-update clean

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

install: ## First-time setup: build, start, and run Spina installer
	docker compose up --build -d
	@echo ""
	@echo "Waiting for Rails to be ready..."
	@tries=0; \
	until curl -s -o /dev/null http://127.0.0.1:3000/up 2>/dev/null; do \
		tries=$$((tries + 1)); \
		if [ $$tries -ge 30 ]; then \
			echo "    Timed out after 5 minutes. Check 'make logs' for errors."; \
			exit 1; \
		fi; \
		echo "    Still waiting..."; \
		sleep 10; \
	done
	@echo ""
	@echo "Running Spina CMS installer..."
	@echo ""
	docker compose exec web bundle exec rails spina:install
	@echo ""
	@echo "Restarting server..."
	docker compose restart web
	@sleep 5
	@echo ""
	@echo "Done! Visit http://127.0.0.1:3000"
	@echo "    Admin: http://127.0.0.1:3000/admin"

up: ## Start services
	docker compose up -d

down: ## Stop all services
	docker compose down

build: ## Rebuild the Docker image
	docker compose build

logs: ## Tail logs from the web service
	docker compose logs -f web

bundle-update: ## Run bundle update
	docker compose exec web bundle update

clean: ## Stop services and remove volumes
	@docker compose run --rm --no-deps web rm -rf \
		db/migrate/*.spina.rb \
		db/migrate/*_create_active_storage_tables.active_storage.rb \
		db/schema.rb \
		config/initializers/spina.rb config/initializers/mobility.rb \
		config/initializers/themes \
		app/views/default app/views/layouts/default \
		app/assets/config/spina \
		2>/dev/null || true
	docker compose down -v
	@echo "Cleaned. Run 'make install' to start fresh."
