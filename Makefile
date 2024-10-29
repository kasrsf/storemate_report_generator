.PHONY: setup test clean process-data generate-reports backup-data install lint

DATA_DIR = data
BACKUP_DIR = backups

setup:
	uv venv
	uv pip install -e ".[dev]"

test:
	uv run pytest tests/ -v --cov=src/storemate_report_generator

clean:
	rm -rf $(DATA_DIR)/processed/*
	rm -rf $(DATA_DIR)/reports/*
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

process-data:
	uv run python -m storemate_report_generator.cli process-data

generate-reports:
	uv run python -m storemate_report_generator.cli generate-reports

backup-data:
	uv run python -m storemate_report_generator.cli backup-data

install:
	uv pip install -e .

lint:
	uv run ruff check . --fix

format:
	uv run ruff format .

# Run the complete pipeline
run-all: process-data generate-reports backup-data
