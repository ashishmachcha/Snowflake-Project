-- =============================================================================
-- PIPELINE AUTOMATION — MASTER EXECUTION GUIDE
-- Database: MOVIE_PROJECT_DB
-- Purpose: Single entry point to deploy the entire pipeline
-- =============================================================================
-- 
-- EXECUTION ORDER:
-- ================
-- 1. bronze_layer.sql          → Storage integrations, stages, table DDL
-- 2. realtime_ingestion.sql    → Snowpipes (auto-ingest from S3)
-- 3. cdc_incremental.sql       → Streams + incremental Silver tables
-- 4. silver_layer.sql          → Silver views (batch alternative)
-- 5. gold_layer.sql            → Gold analytics tables/views
-- 6. orchestration_dag.sql     → Task DAG (Bronze → Silver → Gold)
-- 7. data_quality_tests.sql    → DQ framework + scheduled tests
-- 8. alerting_error_handling.sql → Alerts, notifications, error logging
-- 9. metadata_lineage.sql      → Lineage registry, schema docs, audit
--
-- ARCHITECTURE DIAGRAM:
-- =====================
--
--  ┌─────────────────────────────────────────────────────────────────────┐
--  │                        DATA SOURCES                                  │
--  │  S3 (IMDB/Kaggle/MovieLens)  │  Internal Upload (Netflix)           │
--  └──────────────┬───────────────────────────────┬──────────────────────┘
--                 │ Snowpipe (AUTO_INGEST)         │ Task (5 min poll)
--                 ▼                                ▼
--  ┌─────────────────────────────────────────────────────────────────────┐
--  │                      BRONZE LAYER                                    │
--  │  BRONZE_API  │  BRONZE_API_IMDB  │  BRONZE_API_KAGGLE2  │  ML       │
--  │  (Netflix)   │  (7 tables)       │  (7 tables)          │ (6 tables)│
--  └──────────────┬──────────────────────────────────────────────────────┘
--                 │ Streams (CDC - Change Data Capture)
--                 ▼
--  ┌─────────────────────────────────────────────────────────────────────┐
--  │                      SILVER LAYER                                    │
--  │  Cleaned, typed, deduplicated, incrementally merged                  │
--  │  IMDB_MOVIES_INCREMENTAL  │  MOVIES_METADATA_INCREMENTAL  │  ML     │
--  └──────────────┬──────────────────────────────────────────────────────┘
--                 │ Tasks (DAG chained, conditional execution)
--                 ▼
--  ┌─────────────────────────────────────────────────────────────────────┐
--  │                       GOLD LAYER                                     │
--  │  DIM_MOVIES  │  MOVIE_POPULARITY  │  FINANCIAL_PERFORMANCE          │
--  │  GENRE_PERFORMANCE  │  NETFLIX views  │  USER analytics             │
--  └──────────────┬──────────────────────────────────────────────────────┘
--                 │
--                 ▼
--  ┌──────────────────────────┐    ┌─────────────────────────────────────┐
--  │    STREAMLIT DASHBOARD   │    │        OBSERVABILITY                 │
--  │    (9-tab analytics)     │    │  Alerts │ DQ Tests │ Lineage │ Logs │
--  └──────────────────────────┘    └─────────────────────────────────────┘
--
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- =============================================================================
-- QUICK HEALTH CHECK: Verify all pipeline components exist
-- =============================================================================

-- Check schemas
SELECT SCHEMA_NAME, CREATED FROM MOVIE_PROJECT_DB.INFORMATION_SCHEMA.SCHEMATA ORDER BY CREATED;

-- Check table counts by layer
SELECT
    CASE
        WHEN TABLE_SCHEMA LIKE 'BRONZE%' THEN 'BRONZE'
        WHEN TABLE_SCHEMA = 'SILVER' THEN 'SILVER'
        WHEN TABLE_SCHEMA = 'GOLD' THEN 'GOLD'
        ELSE TABLE_SCHEMA
    END AS LAYER,
    COUNT(*) AS TABLE_COUNT,
    SUM(ROW_COUNT) AS TOTAL_ROWS
FROM MOVIE_PROJECT_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
GROUP BY LAYER
ORDER BY LAYER;

-- Check pipes
SELECT PIPE_SCHEMA, PIPE_NAME, IS_AUTOINGEST_ENABLED
FROM MOVIE_PROJECT_DB.INFORMATION_SCHEMA.PIPES
ORDER BY PIPE_SCHEMA, PIPE_NAME;

-- Check streams
SHOW STREAMS IN DATABASE MOVIE_PROJECT_DB;

-- Check tasks and their state
SHOW TASKS IN DATABASE MOVIE_PROJECT_DB;

-- Check alerts
SHOW ALERTS IN DATABASE MOVIE_PROJECT_DB;

-- =============================================================================
-- MANUAL PIPELINE TRIGGER (use when you want to force a full refresh)
-- =============================================================================

-- Force-execute the root orchestrator (triggers entire DAG)
-- EXECUTE TASK MOVIE_PROJECT_DB.PUBLIC.task_pipeline_orchestrator;

-- Force-execute data quality tests
-- CALL MOVIE_PROJECT_DB.DATA_QUALITY.run_all_tests();

-- =============================================================================
-- COST CONTROL: SUSPEND ALL TASKS (to save trial credits)
-- =============================================================================
-- Uncomment and run to pause everything:

-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_pipeline_orchestrator SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_silver_imdb_refresh SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_silver_kaggle_refresh SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_silver_movielens_refresh SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_gold_dim_movies SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_gold_movie_popularity SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_gold_financial SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_gold_genre_performance SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_dq_post_refresh SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_pipeline_complete SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.DATA_QUALITY.task_run_dq_tests SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_load_internal_netflix SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_load_internal_imdb SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_load_internal_kaggle SUSPEND;
-- ALTER TASK MOVIE_PROJECT_DB.PUBLIC.task_load_internal_movielens SUSPEND;

-- =============================================================================
-- COST CONTROL: PAUSE ALL PIPES (to stop auto-ingest charges)
-- =============================================================================
-- Uncomment and run to pause all pipes:

-- ALTER PIPE MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_title_basics SET PIPE_EXECUTION_PAUSED = TRUE;
-- ALTER PIPE MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_title_ratings SET PIPE_EXECUTION_PAUSED = TRUE;
-- ALTER PIPE MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_name_basics SET PIPE_EXECUTION_PAUSED = TRUE;
-- ALTER PIPE MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.pipe_movies_metadata SET PIPE_EXECUTION_PAUSED = TRUE;
-- ALTER PIPE MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.pipe_ratings SET PIPE_EXECUTION_PAUSED = TRUE;

-- =============================================================================
-- MONITORING QUERIES
-- =============================================================================

-- Recent task executions
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
-- WHERE DATABASE_NAME = 'MOVIE_PROJECT_DB'
-- ORDER BY SCHEDULED_TIME DESC LIMIT 20;

-- Recent pipe loads
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
--   TABLE_NAME => 'MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_BASICS',
--   START_TIME => DATEADD('HOUR', -24, CURRENT_TIMESTAMP())
-- ));

-- Pipeline SLA status
-- SELECT * FROM MOVIE_PROJECT_DB.OBSERVABILITY.PIPELINE_SLA_STATUS;

-- Data quality results
-- SELECT * FROM MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS ORDER BY EXECUTED_AT DESC LIMIT 50;

-- Credit usage today
-- SELECT WAREHOUSE_NAME, SUM(CREDITS_USED) AS TOTAL_CREDITS
-- FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
-- WHERE START_TIME >= CURRENT_DATE()
-- GROUP BY WAREHOUSE_NAME;
