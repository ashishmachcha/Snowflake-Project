-- =============================================================================
-- METADATA, LINEAGE & AUDIT TRACKING
-- Database: MOVIE_PROJECT_DB
-- Purpose: Data lineage documentation, schema registry, audit trails,
--          and operational metadata for the complete pipeline
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

CREATE SCHEMA IF NOT EXISTS MOVIE_PROJECT_DB.METADATA;

-- =============================================================================
-- SECTION 1: DATA LINEAGE REGISTRY
-- Documents source → target relationships across all layers
-- =============================================================================

CREATE TABLE IF NOT EXISTS MOVIE_PROJECT_DB.METADATA.DATA_LINEAGE (
    LINEAGE_ID NUMBER AUTOINCREMENT,
    SOURCE_SYSTEM VARCHAR,       -- S3, API, INTERNAL_UPLOAD
    SOURCE_LOCATION VARCHAR,     -- s3://bucket/path or stage name
    SOURCE_TABLE VARCHAR,        -- Full table name (DB.SCHEMA.TABLE)
    TARGET_TABLE VARCHAR,        -- Full table name
    TRANSFORMATION_TYPE VARCHAR, -- COPY, VIEW, MERGE, CTAS
    TRANSFORMATION_LOGIC VARCHAR,-- Brief description of what happens
    LAYER VARCHAR,               -- BRONZE, SILVER, GOLD
    REFRESH_FREQUENCY VARCHAR,   -- REALTIME, 5_MIN, HOURLY, DAILY
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Populate lineage registry
INSERT INTO MOVIE_PROJECT_DB.METADATA.DATA_LINEAGE
    (SOURCE_SYSTEM, SOURCE_LOCATION, SOURCE_TABLE, TARGET_TABLE, TRANSFORMATION_TYPE, TRANSFORMATION_LOGIC, LAYER, REFRESH_FREQUENCY)
VALUES
    -- Bronze: S3 → Tables (via Snowpipe)
    ('S3', 's3://<YOUR_IMDB_BUCKET>/S3/', 'S3 Files (TSV)', 'MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_BASICS', 'COPY', 'Auto-ingest via Snowpipe, TSV format, gzip compressed', 'BRONZE', 'REALTIME'),
    ('S3', 's3://<YOUR_IMDB_BUCKET>/S3/', 'S3 Files (TSV)', 'MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_RATINGS', 'COPY', 'Auto-ingest via Snowpipe', 'BRONZE', 'REALTIME'),
    ('S3', 's3://<YOUR_IMDB_BUCKET>/S3/', 'S3 Files (TSV)', 'MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_PRINCIPALS', 'COPY', 'Auto-ingest via Snowpipe', 'BRONZE', 'REALTIME'),
    ('S3', 's3://<YOUR_IMDB_BUCKET>/S3/', 'S3 Files (TSV)', 'MOVIE_PROJECT_DB.BRONZE_API_IMDB.NAME_BASICS', 'COPY', 'Auto-ingest via Snowpipe', 'BRONZE', 'REALTIME'),
    ('S3', 's3://<YOUR_KAGGLE_BUCKET>/archive/', 'S3 Files (CSV)', 'MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.MOVIES_METADATA', 'COPY', 'Auto-ingest via Snowpipe, CSV format', 'BRONZE', 'REALTIME'),
    ('S3', 's3://<YOUR_KAGGLE_BUCKET>/archive/', 'S3 Files (CSV)', 'MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.CREDITS', 'COPY', 'Auto-ingest via Snowpipe', 'BRONZE', 'REALTIME'),
    ('S3', 's3://<YOUR_KAGGLE_BUCKET>/archive/', 'S3 Files (CSV)', 'MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.RATINGS', 'COPY', 'Auto-ingest via Snowpipe', 'BRONZE', 'REALTIME'),
    ('S3', 's3://<YOUR_MOVIELENS_BUCKET>/ml-32m/', 'S3 Files (CSV)', 'MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.MOVIES', 'COPY', 'Auto-ingest via Snowpipe', 'BRONZE', 'REALTIME'),
    ('S3', 's3://<YOUR_MOVIELENS_BUCKET>/ml-32m/', 'S3 Files (CSV)', 'MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.RATINGS', 'COPY', 'Auto-ingest via Snowpipe, 32M+ rows', 'BRONZE', 'REALTIME'),
    ('S3', 's3://<YOUR_MOVIELENS_BUCKET>/ml-32m/', 'S3 Files (CSV)', 'MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.TAGS', 'COPY', 'Auto-ingest via Snowpipe', 'BRONZE', 'REALTIME'),
    ('INTERNAL_UPLOAD', '@BRONZE_API.upload_stage', 'Manual CSV Upload', 'MOVIE_PROJECT_DB.BRONZE_API.NETFLIX', 'COPY', 'Manual upload via Snowsight UI, polled every 5 min', 'BRONZE', '5_MIN'),

    -- Silver: Bronze → Clean/Typed (via CDC MERGE)
    ('SNOWFLAKE', 'BRONZE_API_IMDB.TITLE_BASICS + TITLE_RATINGS', 'MOVIE_PROJECT_DB.BRONZE_API_IMDB.*', 'MOVIE_PROJECT_DB.SILVER.IMDB_MOVIES_INCREMENTAL', 'MERGE', 'Join basics+ratings, filter movies only, numvotes>=100, CDC via streams', 'SILVER', '5_MIN'),
    ('SNOWFLAKE', 'BRONZE_API_KAGGLE2.MOVIES_METADATA', 'MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.MOVIES_METADATA', 'MOVIE_PROJECT_DB.SILVER.MOVIES_METADATA_INCREMENTAL', 'MERGE', 'TRY_CAST types, parse dates, filter invalid IDs, CDC via streams', 'SILVER', '5_MIN'),
    ('SNOWFLAKE', 'BRONZE_API_MOVIE_LENS.RATINGS + MOVIES', 'MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.*', 'MOVIE_PROJECT_DB.SILVER.MOVIELENS_RATINGS_INCREMENTAL', 'MERGE', 'Aggregate ratings per movie, rolling average, CDC via streams', 'SILVER', '5_MIN'),

    -- Gold: Silver → Analytics (via scheduled Tasks)
    ('SNOWFLAKE', 'SILVER.MOVIES_METADATA + IMDB_MOVIES', 'MOVIE_PROJECT_DB.SILVER.*', 'MOVIE_PROJECT_DB.GOLD.DIM_MOVIES', 'CTAS', 'Full rebuild of movie dimension, joins Kaggle+IMDB', 'GOLD', '5_MIN'),
    ('SNOWFLAKE', 'SILVER.IMDB + MOVIELENS + KAGGLE', 'MOVIE_PROJECT_DB.SILVER.*', 'MOVIE_PROJECT_DB.GOLD.MOVIE_POPULARITY', 'MERGE', 'Cross-source popularity scoring, incremental merge', 'GOLD', '5_MIN'),
    ('SNOWFLAKE', 'SILVER.MOVIES_METADATA', 'MOVIE_PROJECT_DB.SILVER.MOVIES_METADATA_INCREMENTAL', 'MOVIE_PROJECT_DB.GOLD.FINANCIAL_PERFORMANCE', 'MERGE', 'ROI, profit margin, budget vs revenue calculations', 'GOLD', '5_MIN'),
    ('SNOWFLAKE', 'GOLD.FINANCIAL_PERFORMANCE', 'MOVIE_PROJECT_DB.GOLD.FINANCIAL_PERFORMANCE', 'MOVIE_PROJECT_DB.GOLD.GENRE_PERFORMANCE', 'MERGE', 'Genre-level aggregation from financial data', 'GOLD', '5_MIN');

-- =============================================================================
-- SECTION 2: SCHEMA REGISTRY (documents expected schema contracts)
-- =============================================================================

CREATE TABLE IF NOT EXISTS MOVIE_PROJECT_DB.METADATA.SCHEMA_REGISTRY (
    REGISTRY_ID NUMBER AUTOINCREMENT,
    TABLE_NAME VARCHAR NOT NULL,
    COLUMN_NAME VARCHAR NOT NULL,
    DATA_TYPE VARCHAR NOT NULL,
    IS_NULLABLE BOOLEAN DEFAULT TRUE,
    IS_PRIMARY_KEY BOOLEAN DEFAULT FALSE,
    DESCRIPTION VARCHAR,
    BUSINESS_RULE VARCHAR,
    REGISTERED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Register critical columns
INSERT INTO MOVIE_PROJECT_DB.METADATA.SCHEMA_REGISTRY
    (TABLE_NAME, COLUMN_NAME, DATA_TYPE, IS_NULLABLE, IS_PRIMARY_KEY, DESCRIPTION, BUSINESS_RULE)
VALUES
    ('BRONZE_API_IMDB.TITLE_BASICS', 'TCONST', 'VARCHAR', FALSE, TRUE, 'Unique IMDB title identifier (e.g. tt0000001)', 'Must start with "tt" followed by digits'),
    ('BRONZE_API_IMDB.TITLE_RATINGS', 'AVERAGERATING', 'NUMBER(3,1)', FALSE, FALSE, 'Weighted average IMDB rating', 'Must be between 1.0 and 10.0'),
    ('BRONZE_API_IMDB.TITLE_RATINGS', 'NUMVOTES', 'NUMBER', FALSE, FALSE, 'Number of user votes', 'Must be > 0'),
    ('BRONZE_API_MOVIE_LENS.RATINGS', 'RATING', 'NUMBER(2,1)', FALSE, FALSE, 'User rating on 0.5-5.0 scale', 'Must be between 0.5 and 5.0, in 0.5 increments'),
    ('BRONZE_API_MOVIE_LENS.RATINGS', 'USER_ID', 'NUMBER', FALSE, FALSE, 'Anonymous user identifier', 'Must be > 0'),
    ('BRONZE_API_KAGGLE2.MOVIES_METADATA', 'ID', 'VARCHAR', FALSE, TRUE, 'TMDB movie ID (stored as VARCHAR, cast to NUMBER)', 'Must be castable to NUMBER'),
    ('GOLD.MOVIE_POPULARITY', 'TCONST', 'VARCHAR', FALSE, TRUE, 'IMDB title ID - primary key for popularity table', 'Foreign key to DIM_MOVIES'),
    ('GOLD.FINANCIAL_PERFORMANCE', 'ROI', 'FLOAT', TRUE, FALSE, 'Return on Investment percentage', 'NULL when budget is 0');

-- =============================================================================
-- SECTION 3: AUDIT TRAIL (who changed what, when)
-- =============================================================================

CREATE TABLE IF NOT EXISTS MOVIE_PROJECT_DB.METADATA.AUDIT_TRAIL (
    AUDIT_ID NUMBER AUTOINCREMENT,
    ACTION VARCHAR NOT NULL,        -- CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, GRANT
    OBJECT_TYPE VARCHAR,            -- TABLE, VIEW, TASK, PIPE, STREAM
    OBJECT_NAME VARCHAR,
    PERFORMED_BY VARCHAR DEFAULT CURRENT_USER(),
    PERFORMED_ROLE VARCHAR DEFAULT CURRENT_ROLE(),
    DETAIL VARCHAR,
    ROW_COUNT_BEFORE NUMBER,
    ROW_COUNT_AFTER NUMBER,
    EXECUTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- =============================================================================
-- SECTION 4: DATA DICTIONARY VIEW (auto-generated from information schema)
-- =============================================================================

CREATE OR REPLACE VIEW MOVIE_PROJECT_DB.METADATA.DATA_DICTIONARY AS
SELECT
    c.TABLE_SCHEMA,
    c.TABLE_NAME,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.IS_NULLABLE,
    c.ORDINAL_POSITION,
    sr.IS_PRIMARY_KEY,
    sr.DESCRIPTION,
    sr.BUSINESS_RULE
FROM MOVIE_PROJECT_DB.INFORMATION_SCHEMA.COLUMNS c
LEFT JOIN MOVIE_PROJECT_DB.METADATA.SCHEMA_REGISTRY sr
    ON c.TABLE_SCHEMA || '.' || c.TABLE_NAME = sr.TABLE_NAME
    AND c.COLUMN_NAME = sr.COLUMN_NAME
WHERE c.TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA', 'METADATA', 'DATA_QUALITY', 'OBSERVABILITY')
ORDER BY c.TABLE_SCHEMA, c.TABLE_NAME, c.ORDINAL_POSITION;

-- =============================================================================
-- SECTION 5: PIPELINE METRICS DASHBOARD VIEW
-- =============================================================================

CREATE OR REPLACE VIEW MOVIE_PROJECT_DB.METADATA.PIPELINE_METRICS AS
SELECT
    dl.SOURCE_SYSTEM,
    dl.LAYER,
    dl.SOURCE_TABLE,
    dl.TARGET_TABLE,
    dl.TRANSFORMATION_TYPE,
    dl.REFRESH_FREQUENCY,
    t.ROW_COUNT AS CURRENT_ROW_COUNT,
    t.BYTES AS TABLE_SIZE_BYTES,
    t.LAST_ALTERED AS LAST_MODIFIED
FROM MOVIE_PROJECT_DB.METADATA.DATA_LINEAGE dl
LEFT JOIN MOVIE_PROJECT_DB.INFORMATION_SCHEMA.TABLES t
    ON dl.TARGET_TABLE = 'MOVIE_PROJECT_DB.' || t.TABLE_SCHEMA || '.' || t.TABLE_NAME
WHERE dl.IS_ACTIVE = TRUE
ORDER BY dl.LAYER, dl.TARGET_TABLE;

-- =============================================================================
-- SECTION 6: PROJECT OVERVIEW VIEW (for Streamlit dashboard)
-- =============================================================================

CREATE OR REPLACE VIEW MOVIE_PROJECT_DB.METADATA.PROJECT_OVERVIEW AS
SELECT
    'Data Sources' AS CATEGORY, COUNT(DISTINCT SOURCE_SYSTEM) AS COUNT_VAL
FROM MOVIE_PROJECT_DB.METADATA.DATA_LINEAGE WHERE LAYER = 'BRONZE'
UNION ALL
SELECT 'Bronze Tables', COUNT(*) FROM MOVIE_PROJECT_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('BRONZE_API', 'BRONZE_API_IMDB', 'BRONZE_API_KAGGLE2', 'BRONZE_API_MOVIE_LENS') AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'Silver Tables/Views', COUNT(*) FROM MOVIE_PROJECT_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'SILVER'
UNION ALL
SELECT 'Gold Tables/Views', COUNT(*) FROM MOVIE_PROJECT_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'GOLD'
UNION ALL
SELECT 'Active Pipes', COUNT(*) FROM MOVIE_PROJECT_DB.INFORMATION_SCHEMA.PIPES
UNION ALL
SELECT 'Active Streams', COUNT(*) FROM MOVIE_PROJECT_DB.INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA = 'BRONZE_API_IMDB';
