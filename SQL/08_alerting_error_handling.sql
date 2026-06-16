-- =============================================================================
-- ERROR HANDLING, ALERTING & NOTIFICATION
-- Database: MOVIE_PROJECT_DB
-- Purpose: Email alerts on pipeline failures, error logging, SLA breach detection
-- Depends on: pipeline_automation.sql
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- =============================================================================
-- SECTION 1: NOTIFICATION INTEGRATION (Email Alerts)
-- =============================================================================

CREATE OR REPLACE NOTIFICATION INTEGRATION movie_pipeline_email_alerts
  TYPE = EMAIL
  ENABLED = TRUE
  COMMENT = 'Email notifications for pipeline failures and SLA breaches';

-- =============================================================================
-- SECTION 2: ERROR LOG TABLE
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS MOVIE_PROJECT_DB.OBSERVABILITY;

CREATE TABLE IF NOT EXISTS MOVIE_PROJECT_DB.OBSERVABILITY.ERROR_LOG (
    ERROR_ID NUMBER AUTOINCREMENT,
    ERROR_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    TASK_NAME VARCHAR,
    PIPE_NAME VARCHAR,
    ERROR_CODE VARCHAR,
    ERROR_MESSAGE VARCHAR,
    ERROR_SEVERITY VARCHAR,    -- CRITICAL, WARNING, INFO
    SOURCE_SCHEMA VARCHAR,
    ROWS_AFFECTED NUMBER,
    RESOLVED BOOLEAN DEFAULT FALSE,
    RESOLVED_AT TIMESTAMP_NTZ,
    RESOLVED_BY VARCHAR
);

-- =============================================================================
-- SECTION 3: PIPELINE EXECUTION LOG (enhanced)
-- =============================================================================

CREATE TABLE IF NOT EXISTS MOVIE_PROJECT_DB.OBSERVABILITY.PIPELINE_EXECUTION_LOG (
    EXECUTION_ID NUMBER AUTOINCREMENT,
    TASK_NAME VARCHAR NOT NULL,
    TASK_TYPE VARCHAR,          -- CDC, BATCH, QUALITY_CHECK, ALERT
    SOURCE_SCHEMA VARCHAR,
    TARGET_TABLE VARCHAR,
    STATUS VARCHAR,             -- RUNNING, SUCCESS, FAILED, SKIPPED
    ROWS_INSERTED NUMBER DEFAULT 0,
    ROWS_UPDATED NUMBER DEFAULT 0,
    ROWS_DELETED NUMBER DEFAULT 0,
    EXECUTION_START TIMESTAMP_NTZ,
    EXECUTION_END TIMESTAMP_NTZ,
    DURATION_SECONDS NUMBER,
    ERROR_MESSAGE VARCHAR,
    WAREHOUSE_NAME VARCHAR,
    CREDITS_USED FLOAT
);

-- =============================================================================
-- SECTION 4: ALERT — TASK FAILURE DETECTION
-- Fires when any pipeline task fails in the last 15 minutes
-- =============================================================================

CREATE OR REPLACE ALERT MOVIE_PROJECT_DB.OBSERVABILITY.alert_task_failure
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
    WHERE STATE = 'FAILED'
      AND DATABASE_NAME = 'MOVIE_PROJECT_DB'
      AND COMPLETED_TIME >= DATEADD('MINUTE', -15, CURRENT_TIMESTAMP())
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'movie_pipeline_email_alerts',
      'ashishmachcha7@gmail.com',
      'ALERT: Movie Pipeline Task Failed',
      'One or more pipeline tasks in MOVIE_PROJECT_DB have FAILED in the last 15 minutes. Please check TASK_HISTORY for details.\n\nTimestamp: ' || CURRENT_TIMESTAMP()::VARCHAR
    );

-- =============================================================================
-- SECTION 5: ALERT — DATA FRESHNESS (SLA Breach)
-- Fires when Gold tables haven't been updated in 30+ minutes
-- =============================================================================

CREATE OR REPLACE ALERT MOVIE_PROJECT_DB.OBSERVABILITY.alert_data_staleness
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '15 MINUTE'
  IF (EXISTS (
    SELECT 1
    FROM MOVIE_PROJECT_DB.GOLD.MOVIE_POPULARITY
    WHERE MAX(LAST_UPDATED) < DATEADD('MINUTE', -30, CURRENT_TIMESTAMP())
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'movie_pipeline_email_alerts',
      'ashishmachcha7@gmail.com',
      'WARNING: Data Staleness Detected',
      'Gold layer tables have not been refreshed in 30+ minutes. CDC pipeline may be stuck.\n\nCheck streams and tasks for issues.'
    );

-- =============================================================================
-- SECTION 6: ALERT — SNOWPIPE FAILURE
-- Fires when any pipe has errors in the last hour
-- =============================================================================

CREATE OR REPLACE ALERT MOVIE_PROJECT_DB.OBSERVABILITY.alert_pipe_failure
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '15 MINUTE'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
    WHERE STATUS = 'LOAD_FAILED'
      AND TABLE_CATALOG_NAME = 'MOVIE_PROJECT_DB'
      AND LAST_LOAD_TIME >= DATEADD('HOUR', -1, CURRENT_TIMESTAMP())
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'movie_pipeline_email_alerts',
      'ashishmachcha7@gmail.com',
      'ALERT: Snowpipe Load Failed',
      'One or more Snowpipe loads have FAILED in the last hour. Check COPY_HISTORY for file-level errors.'
    );

-- =============================================================================
-- SECTION 7: ALERT — CREDIT USAGE SPIKE
-- Fires when hourly credit usage exceeds threshold (protect trial credits!)
-- =============================================================================

CREATE OR REPLACE ALERT MOVIE_PROJECT_DB.OBSERVABILITY.alert_credit_spike
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '30 MINUTE'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
    WHERE WAREHOUSE_NAME = 'COMPUTE_WH'
      AND START_TIME >= DATEADD('HOUR', -1, CURRENT_TIMESTAMP())
    HAVING SUM(CREDITS_USED) > 2  -- Alert if >2 credits burned in 1 hour
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'movie_pipeline_email_alerts',
      'ashishmachcha7@gmail.com',
      'WARNING: High Credit Usage',
      'COMPUTE_WH has consumed >2 credits in the last hour. Consider suspending non-critical tasks to preserve trial credits.'
    );

-- =============================================================================
-- SECTION 8: STORED PROCEDURE — CENTRALIZED ERROR HANDLER
-- Call this from any task to log errors consistently
-- =============================================================================

CREATE OR REPLACE PROCEDURE MOVIE_PROJECT_DB.OBSERVABILITY.log_error(
    P_TASK_NAME VARCHAR,
    P_ERROR_CODE VARCHAR,
    P_ERROR_MESSAGE VARCHAR,
    P_SEVERITY VARCHAR,
    P_SOURCE_SCHEMA VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    INSERT INTO MOVIE_PROJECT_DB.OBSERVABILITY.ERROR_LOG
        (TASK_NAME, ERROR_CODE, ERROR_MESSAGE, ERROR_SEVERITY, SOURCE_SCHEMA)
    VALUES
        (:P_TASK_NAME, :P_ERROR_CODE, :P_ERROR_MESSAGE, :P_SEVERITY, :P_SOURCE_SCHEMA);
    RETURN 'Error logged successfully';
END;

-- =============================================================================
-- SECTION 9: STORED PROCEDURE — LOG PIPELINE EXECUTION
-- =============================================================================

CREATE OR REPLACE PROCEDURE MOVIE_PROJECT_DB.OBSERVABILITY.log_execution(
    P_TASK_NAME VARCHAR,
    P_TASK_TYPE VARCHAR,
    P_SOURCE_SCHEMA VARCHAR,
    P_TARGET_TABLE VARCHAR,
    P_STATUS VARCHAR,
    P_ROWS_INSERTED NUMBER,
    P_ROWS_UPDATED NUMBER,
    P_ERROR_MESSAGE VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    INSERT INTO MOVIE_PROJECT_DB.OBSERVABILITY.PIPELINE_EXECUTION_LOG
        (TASK_NAME, TASK_TYPE, SOURCE_SCHEMA, TARGET_TABLE, STATUS,
         ROWS_INSERTED, ROWS_UPDATED, EXECUTION_END)
    VALUES
        (:P_TASK_NAME, :P_TASK_TYPE, :P_SOURCE_SCHEMA, :P_TARGET_TABLE, :P_STATUS,
         :P_ROWS_INSERTED, :P_ROWS_UPDATED, CURRENT_TIMESTAMP());
    RETURN 'Execution logged';
END;

-- =============================================================================
-- SECTION 10: RESUME ALERTS
-- =============================================================================

ALTER ALERT MOVIE_PROJECT_DB.OBSERVABILITY.alert_task_failure RESUME;
ALTER ALERT MOVIE_PROJECT_DB.OBSERVABILITY.alert_data_staleness RESUME;
ALTER ALERT MOVIE_PROJECT_DB.OBSERVABILITY.alert_pipe_failure RESUME;
ALTER ALERT MOVIE_PROJECT_DB.OBSERVABILITY.alert_credit_spike RESUME;

-- =============================================================================
-- VERIFY
-- =============================================================================
SHOW ALERTS IN SCHEMA MOVIE_PROJECT_DB.OBSERVABILITY;
