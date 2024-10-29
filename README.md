# Storemate Report Generator

A pytho-based tool for processing store DBF data files and generating analytical reports using DuckDB.

## Features
* Automatic processing of DBF files to CSV format
* Report generation using configurable SQL queries
* Automatic backup of data directory
* Command-line interface for easy operation

## Prerequisites
* Python 3.9 or higer
* UV Package manager (`pip install uv`)

## Installation
1. Clone the repository:
```bash
git clone https://github.com/kasrsf/storemate_report_generator.git
cd storemate_report_generator 
```

2. Set up the development environment
```bash
make setup 
```

## Usage

### Directory Structure

* `data/raw`: Place your DBF files here
* `data/processed/`: Converted CSV files and DuckDB database
* `data/reports/`: Generated report files
* `reports/queries/`: YAML files containing report queries

### Commands
1. Process DBF files to CSV:
```bash
make process-data 
```

2. Generate reports:
```bash
make generate-reports 
```

3. Backup data directory:
```bash
make backup-data
```

4. Run complete pipeline (process, generate reports, backup):
```bash
make run-all 
```

### Adding New Reports

Create a new YAML file in `reports/queries/` directory with the following structure:

```yaml
name: weekly_customer_sales
description: "Breakdown of sales by customers and items in the past week"
query: |
  SELECT
    customer_name,
    item_name,
    SUM(quantity) AS total_quantity,
    SUM(amount) AS total_amount
  FROM sales
  WHERE data >= DATEADD('week', -1, CURRENT_DATE)
  GROUP BY customer_name, item_name
  ORDER BY total_amount DESC
output_file: weekly_customer_sales.csv
```

## Development

### Running Tests
```bash
make test
```

### Code Quality
```bash
make lint
make format
```

## License
MIT License
