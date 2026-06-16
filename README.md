# Snowflake Real-Time Data Pipeline

## Overview

End-to-end data pipeline on Snowflake using **medallion architecture** (Bronze → Silver → Gold) with real-time ingestion via Snowpipe, CDC (Change Data Capture), automated data quality checks, and monitoring via Streamlit.

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   AWS S3    │───▶│   Bronze    │───▶│   Silver    │───▶│    Gold     │
│  (Sources)  │    │  (Raw Data) │    │  (Cleaned)  │    │ (Analytics) │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │                  │
   Snowpipe          Streams/CDC       MERGE Tasks         Scheduled
  Auto-Ingest                                              Aggregations
```

## Data Sources

| Source | Format | Ingestion Method |
|--------|--------|-----------------|
| IMDB | TSV (gzip) | Snowpipe auto-ingest from S3 |
| Kaggle (TMDb) | CSV | Snowpipe auto-ingest from S3 |
| MovieLens (32M) | CSV | Snowpipe auto-ingest from S3 |
| Netflix | CSV | Manual upload via internal stage |

## Project Structure

```
snowflake-movie-pipeline/
├── README.md
├── .gitignore
├── config.example.env               ← AWS config placeholders (safe to push)
│
├── sql/
│   ├── 01_bronze_layer.sql          ← DB, schemas, integrations, stages, tables
│   ├── 02_realtime_ingestion.sql    ← Snowpipe definitions, auto-ingest
│   ├── 03_silver_layer.sql          ← Cleaned/typed tables, CDC streams
│   ├── 04_cdc_incremental.sql       ← CDC merge logic
│   ├── 05_gold_layer.sql            ← Analytics aggregations
│   ├── 06_data_quality_tests.sql    ← Automated validation checks
│   ├── 07_dead_letter_queue.sql     ← Failed record handling
│   ├── 08_alerting_error_handling.sql ← Alerts & monitoring
│   ├── 09_metadata_lineage.sql      ← Data lineage tracking
│   ├── 10_orchestration_dag.sql     ← Task DAG scheduling
│   └── 11_pipeline_automation.sql   ← End-to-end automation
│
└── streamlit/
    ├── streamlit_app.py             ← Monitoring dashboard
    ├── snowflake.yml                ← Streamlit app config
    └── pyproject.toml               ← Python dependencies
```

## Setup Instructions

### Prerequisites
- Snowflake account with ACCOUNTADMIN role
- AWS account with S3 buckets configured
- IAM roles with trust policy for Snowflake

### Step 1: Configure AWS Credentials
1. Copy `config.example.env` to `.env` (stays local, ignored by git)
2. Fill in your real AWS values in `.env`
3. Do a find-and-replace across the `sql/` files using the mapping in `.env`:

| Placeholder | Replace with |
|-------------|-------------|
| `<YOUR_AWS_ACCOUNT_ID>` | Your 12-digit AWS account ID |
| `<YOUR_IMDB_BUCKET>` | S3 bucket name for IMDB data |
| `<YOUR_KAGGLE_BUCKET>` | S3 bucket name for Kaggle data |
| `<YOUR_MOVIELENS_BUCKET>` | S3 bucket name for MovieLens data |
| `<YOUR_IMDB_ROLE>` | IAM role for IMDB bucket |
| `<YOUR_KAGGLE_ROLE>` | IAM role for Kaggle bucket |
| `<YOUR_MOVIELENS_ROLE>` | IAM role for MovieLens bucket |

### Step 2: Execute SQL Files (in order)
Run each file in Snowsight or SnowSQL in the numbered order:

```
sql/01_bronze_layer.sql          → Creates database, schemas, integrations, stages, tables
sql/02_realtime_ingestion.sql    → Creates Snowpipes for auto-ingest
sql/03_silver_layer.sql          → Creates silver layer tables and streams
sql/04_cdc_incremental.sql       → Creates CDC merge tasks
sql/05_gold_layer.sql            → Creates gold layer analytics tables
sql/06_data_quality_tests.sql    → Sets up data quality checks
sql/07_dead_letter_queue.sql     → Configures error handling
sql/08_alerting_error_handling.sql → Sets up alerting
sql/09_metadata_lineage.sql      → Registers data lineage
sql/10_orchestration_dag.sql     → Creates task DAG
sql/11_pipeline_automation.sql   → Enables full automation
```

### Step 3: Configure S3 Event Notifications
See comments in `sql/02_realtime_ingestion.sql` Section 4 for AWS Console setup.

### Step 4: Deploy Streamlit Dashboard
Deploy the Streamlit app via Snowsight for pipeline monitoring.

## Tech Stack
- **Snowflake** — Data warehouse, Streams, Tasks, Snowpipe
- **AWS S3** — External data lake storage
- **Streamlit** — Pipeline monitoring dashboard
- **Python** — Streamlit app logic

## Key Features
- Real-time ingestion via Snowpipe with auto-ingest
- CDC (Change Data Capture) using Snowflake Streams
- Incremental processing with MERGE statements
- Data quality validation with automated alerts
- Dead letter queue for failed records
- Full data lineage tracking
- Orchestrated task DAG with dependency management
- Streamlit monitoring dashboard
