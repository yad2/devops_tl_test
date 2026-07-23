.PHONY: up down logs test smoke

up:
	docker compose up -d --build

down:
	docker compose down -v

logs:
	docker compose logs -f generator

test:
	docker compose build generator
	docker compose run --rm --no-deps generator pytest -q

smoke:
	docker compose --profile smoke run --rm --build smoke
