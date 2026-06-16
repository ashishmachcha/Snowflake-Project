-- =============================================================================
-- DATA QUALITY TESTING FRAMEWORK
-- Database: MOVIE_PROJECT_DB
-- Purpose: Automated data quality checks, schema validation, row count assertions,
--          referential integrity tests, and freshness monitoring
-- Depends on: bronze_layer.sql, silver_layer.sql, gold_layer.sql
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

CREATE SCHEMA IF NOT EXISTS MOVIE_PROJECT_DB.DATA_QUALITY;

-- =============================================================================
-- SECTION 1: TEST RESULTS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS (
    TEST_ID NUMBER AUTOINCREMENT,
    TEST_NAME VARCHAR NOT NULL,
    TEST_CATEGORY VARCHAR,      -- SCHEMA, FRESHNESS, COMPLETENESS, UNIQUENESS, REFERENTIAL, RANGE
    TABLE_NAME VARCHAR,
    COLUMN_NAME VARCHAR,
    EXPECTED_VALUE VARCHAR,
    ACTUAL_VALUE VARCHAR,
    STATUS VARCHAR,             -- PASS, FAIL, WARN
    ERROR_DETAIL VARCHAR,
    EXECUTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- =============================================================================
-- SECTION 2: STORED PROCEDURE — RUN ALL DATA QUALITY TESTS
-- =============================================================================

CREATE OR REPLACE PROCEDURE MOVIE_PROJECT_DB.DATA_QUALITY.run_all_tests()
RETURNS TABLE(TEST_NAME VARCHAR, STATUS VARCHAR, DETAIL VARCHAR)
LANGUAGE SQL
AS
DECLARE
    res RESULTSET;
BEGIN
    -- Clear previous results
    DELETE FROM MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
    WHERE EXECUTED_AT < DATEADD('DAY', -7, CURRENT_TIMESTAMP());

    -- =========================================================================
    -- TEST 1: ROW COUNT ASSERTIONS (tables should not be empty)
    -- =========================================================================
    INSERT INTO MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        (TEST_NAME, TEST_CATEGORY, TABLE_NAME, EXPECTED_VALUE, ACTUAL_VALUE, STATUS, ERROR_DETAIL)
    SELECT
        'row_count_not_empty' AS TEST_NAME,
        'COMPLETENESS' AS TEST_CATEGORY,
        TABLE_NAME,
        '> 0' AS EXPECTED_VALUE,
        ROW_COUNT::VARCHAR AS ACTUAL_VALUE,
        CASE WHEN ROW_COUNT > 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS,
        CASE WHEN ROW_COUNT = 0 THEN 'Table is empty - data may not be loading' ELSE NULL END
    FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
    WHERE TABLE_CATALOG = 'MOVIE_PROJECT_DB'
      AND TABLE_SCHEMA IN ('BRONZE_API', 'BRONZE_API_IMDB', 'BRONZE_API_KAGGLE2', 'BRONZE_API_MOVIE_LENS')
      AND DELETED IS NULL;

    -- =========================================================================
    -- TEST 2: NULL KEY FIELD CHECK (primary keys should never be null)
    -- =========================================================================

    -- IMDB: TCONST should never be null
    INSERT INTO MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        (TEST_NAME, TEST_CATEGORY, TABLE_NAME, COLUMN_NAME, EXPECTED_VALUE, ACTUAL_VALUE, STATUS, ERROR_DETAIL)
    SELECT
        'null_check_primary_key',
        'COMPLETENESS',
        'BRONZE_API_IMDB.TITLE_BASICS',
        'TCONST',
        '0',
        COUNT_IF(TCONST IS NULL)::VARCHAR,
        CASE WHEN COUNT_IF(TCONST IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN COUNT_IF(TCONST IS NULL) > 0 THEN 'Found ' || COUNT_IF(TCONST IS NULL) || ' null TCONST values' ELSE NULL END
    FROM MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_BASICS;

    -- MovieLens: MOVIE_ID should never be null
    INSERT INTO MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        (TEST_NAME, TEST_CATEGORY, TABLE_NAME, COLUMN_NAME, EXPECTED_VALUE, ACTUAL_VALUE, STATUS, ERROR_DETAIL)
    SELECT
        'null_check_primary_key',
        'COMPLETENESS',
        'BRONZE_API_MOVIE_LENS.MOVIES',
        'MOVIE_ID',
        '0',
        COUNT_IF(MOVIE_ID IS NULL)::VARCHAR,
        CASE WHEN COUNT_IF(MOVIE_ID IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN COUNT_IF(MOVIE_ID IS NULL) > 0 THEN 'Found ' || COUNT_IF(MOVIE_ID IS NULL) || ' null MOVIE_ID values' ELSE NULL END
    FROM MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.MOVIES;

    -- Kaggle: ID should be castable to NUMBER
    INSERT INTO MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        (TEST_NAME, TEST_CATEGORY, TABLE_NAME, COLUMN_NAME, EXPECTED_VALUE, ACTUAL_VALUE, STATUS, ERROR_DETAIL)
    SELECT
        'type_cast_check',
        'SCHEMA',
        'BRONZE_API_KAGGLE2.MOVIES_METADATA',
        'ID',
        '0 non-castable',
        COUNT_IF(TRY_CAST(ID AS NUMBER) IS NULL AND ID IS NOT NULL)::VARCHAR,
        CASE WHEN COUNT_IF(TRY_CAST(ID AS NUMBER) IS NULL AND ID IS NOT NULL) < 10 THEN 'PASS' ELSE 'WARN' END,
        'Found ' || COUNT_IF(TRY_CAST(ID AS NUMBER) IS NULL AND ID IS NOT NULL) || ' IDs that cannot cast to NUMBER'
    FROM MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.MOVIES_METADATA;

    -- =========================================================================
    -- TEST 3: UNIQUENESS CHECKS (no duplicate primary keys)
    -- =========================================================================

    INSERT INTO MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        (TEST_NAME, TEST_CATEGORY, TABLE_NAME, COLUMN_NAME, EXPECTED_VALUE, ACTUAL_VALUE, STATUS, ERROR_DETAIL)
    SELECT
        'uniqueness_check',
        'UNIQUENESS',
        'BRONZE_API_IMDB.TITLE_BASICS',
        'TCONST',
        '0 duplicates',
        (COUNT(*) - COUNT(DISTINCT TCONST))::VARCHAR,
        CASE WHEN COUNT(*) = COUNT(DISTINCT TCONST) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN COUNT(*) != COUNT(DISTINCT TCONST) THEN 'Found ' || (COUNT(*) - COUNT(DISTINCT TCONST)) || ' duplicate TCONST entries' ELSE NULL END
    FROM MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_BASICS;

    INSERT INTO MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        (TEST_NAME, TEST_CATEGORY, TABLE_NAME, COLUMN_NAME, EXPECTED_VALUE, ACTUAL_VALUE, STATUS, ERROR_DETAIL)
    SELECT
        'uniqueness_check',
        'UNIQUENESS',
        'BRONZE_API_MOVIE_LENS.MOVIES',
        'MOVIE_ID',
        '0 duplicates',
        (COUNT(*) - COUNT(DISTINCT MOVIE_ID))::VARCHAR,
        CASE WHEN COUNT(*) = COUNT(DISTINCT MOVIE_ID) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN COUNT(*) != COUNT(DISTINCT MOVIE_ID) THEN 'Found ' || (COUNT(*) - COUNT(DISTINCT MOVIE_ID)) || ' duplicate MOVIE_ID entries' ELSE NULL END
    FROM MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.MOVIES;

    -- =========================================================================
    -- TEST 4: REFERENTIAL INTEGRITY (foreign keys exist in parent table)
    -- =========================================================================

    -- Ratings reference valid movies
    INSERT INTO MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        (TEST_NAME, TEST_CATEGORY, TABLE_NAME, COLUMN_NAME, EXPECTED_VALUE, ACTUAL_VALUE, STATUS, ERROR_DETAIL)
    SELECT
        'referential_integrity',
        'REFERENTIAL',
        'BRONZE_API_MOVIE_LENS.RATINGS → MOVIES',
        'MOVIE_ID',
        '0 orphans',
        COUNT(*)::VARCHAR,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' WHEN COUNT(*) < 100 THEN 'WARN' ELSE 'FAIL' END,
        'Found ' || COUNT(*) || ' ratings referencing non-existent MOVIE_IDs'
    FROM MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.RATINGS r
    LEFT JOIN MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.MOVIES m ON r.MOVIE_ID = m.MOVIE_ID
    WHERE m.MOVIE_ID IS NULL;

    -- IMDB principals reference valid titles
    INSERT INTO MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        (TEST_NAME, TEST_CATEGORY, TABLE_NAME, COLUMN_NAME, EXPECTED_VALUE, ACTUAL_VALUE, STATUS, ERROR_DETAIL)
    SELECT
        'referential_integrity',
        'REFERENTIAL',
        'BRONZE_API_IMDB.TITLE_PRINCIPALS → TITLE_BASICS',
        'TCONST',
        '0 orphans',
        COUNT(*)::VARCHAR,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' WHEN COUNT(*) < 1000 THEN 'WARN' ELSE 'FAIL' END,
        'Found ' || COUNT(*) || ' principals referencing non-existent titles'
    FROM MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_PRINCIPALS tp
    LEFT JOIN MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_BASICS tb ON tp.TCONST = tb.TCONST
    WHERE tb.TCONST IS NULL;

    -- =========================================================================
    -- TEST 5: VALUE RANGE CHECKS (data within expected bounds)
    -- =========================================================================

    -- IMDB ratings should be between 1.0 and 10.0
    INSERT INTO MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        (TEST_NAME, TEST_CATEGORY, TABLE_NAME, COLUMN_NAME, EXPECTED_VALUE, ACTUAL_VALUE, STATUS, ERROR_DETAIL)
    SELECT
        'range_check',
        'RANGE',
        'BRONZE_API_IMDB.TITLE_RATINGS',
        'AVERAGERATING',
        '1.0 - 10.0',
        MIN(AVERAGERATING)::VARCHAR || ' - ' || MAX(AVERAGERATING)::VARCHAR,
        CASE WHEN MIN(AVERAGERATING) >= 1.0 AND MAX(AVERAGERATING) <= 10.0 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN MIN(AVERAGERATING) < 1.0 OR MAX(AVERAGERATING) > 10.0 THEN 'Ratings outside expected range' ELSE NULL END
    FROM MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_RATINGS;

    -- MovieLens ratings should be between 0.5 and 5.0
    INSERT INTO MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        (TEST_NAME, TEST_CATEGORY, TABLE_NAME, COLUMN_NAME, EXPECTED_VALUE, ACTUAL_VALUE, STATUS, ERROR_DETAIL)
    SELECT
        'range_check',
        'RANGE',
        'BRONZE_API_MOVIE_LENS.RATINGS',
        'RATING',
        '0.5 - 5.0',
        MIN(RATING)::VARCHAR || ' - ' || MAX(RATING)::VARCHAR,
        CASE WHEN MIN(RATING) >= 0.5 AND MAX(RATING) <= 5.0 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN MIN(RATING) < 0.5 OR MAX(RATING) > 5.0 THEN 'Ratings outside expected 0.5-5.0 range' ELSE NULL END
    FROM MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.RATINGS;

    -- Release years should be reasonable (1880 - current year)
    INSERT INTO MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        (TEST_NAME, TEST_CATEGORY, TABLE_NAME, COLUMN_NAME, EXPECTED_VALUE, ACTUAL_VALUE, STATUS, ERROR_DETAIL)
    SELECT
        'range_check',
        'RANGE',
        'BRONZE_API_IMDB.TITLE_BASICS',
        'STARTYEAR',
        '1880 - ' || YEAR(CURRENT_DATE())::VARCHAR,
        MIN(STARTYEAR)::VARCHAR || ' - ' || MAX(STARTYEAR)::VARCHAR,
        CASE WHEN MIN(STARTYEAR) >= 1880 AND MAX(STARTYEAR) <= YEAR(CURRENT_DATE()) + 5 THEN 'PASS' ELSE 'WARN' END,
        'Year range: ' || MIN(STARTYEAR)::VARCHAR || ' to ' || MAX(STARTYEAR)::VARCHAR
    FROM MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_BASICS
    WHERE STARTYEAR IS NOT NULL;

    -- =========================================================================
    -- TEST 6: DATA FRESHNESS (tables updated recently)
    -- =========================================================================

    INSERT INTO MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        (TEST_NAME, TEST_CATEGORY, TABLE_NAME, EXPECTED_VALUE, ACTUAL_VALUE, STATUS, ERROR_DETAIL)
    SELECT
        'freshness_check',
        'FRESHNESS',
        TABLE_NAME,
        'Modified within 7 days',
        DATEDIFF('DAY', LAST_ALTERED, CURRENT_TIMESTAMP())::VARCHAR || ' days ago',
        CASE
            WHEN DATEDIFF('DAY', LAST_ALTERED, CURRENT_TIMESTAMP()) <= 7 THEN 'PASS'
            WHEN DATEDIFF('DAY', LAST_ALTERED, CURRENT_TIMESTAMP()) <= 30 THEN 'WARN'
            ELSE 'FAIL'
        END,
        CASE WHEN DATEDIFF('DAY', LAST_ALTERED, CURRENT_TIMESTAMP()) > 7
            THEN 'Table last modified ' || DATEDIFF('DAY', LAST_ALTERED, CURRENT_TIMESTAMP()) || ' days ago'
            ELSE NULL END
    FROM MOVIE_PROJECT_DB.INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA IN ('BRONZE_API', 'BRONZE_API_IMDB', 'BRONZE_API_KAGGLE2', 'BRONZE_API_MOVIE_LENS', 'GOLD')
      AND TABLE_TYPE = 'BASE TABLE';

    -- Return summary
    res := (
        SELECT TEST_NAME, STATUS, COALESCE(ERROR_DETAIL, 'OK') AS DETAIL
        FROM MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
        WHERE EXECUTED_AT >= DATEADD('MINUTE', -5, CURRENT_TIMESTAMP())
        ORDER BY STATUS DESC, TEST_NAME
    );
    RETURN TABLE(res);
END;

-- =============================================================================
-- SECTION 3: SCHEDULED TASK — RUN DQ TESTS EVERY HOUR
-- =============================================================================

CREATE OR REPLACE TASK MOVIE_PROJECT_DB.DATA_QUALITY.task_run_dq_tests
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '60 MINUTE'
  COMMENT = 'Runs all data quality tests hourly and logs results'
AS
  CALL MOVIE_PROJECT_DB.DATA_QUALITY.run_all_tests();

-- =============================================================================
-- SECTION 4: ALERT — DQ TEST FAILURE
-- =============================================================================

CREATE OR REPLACE ALERT MOVIE_PROJECT_DB.DATA_QUALITY.alert_dq_failure
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '60 MINUTE'
  IF (EXISTS (
    SELECT 1
    FROM MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
    WHERE STATUS = 'FAIL'
      AND EXECUTED_AT >= DATEADD('HOUR', -1, CURRENT_TIMESTAMP())
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'movie_pipeline_email_alerts',
      'ashishmachcha7@gmail.com',
      'DATA QUALITY ALERT: Tests Failed',
      'One or more data quality tests have FAILED. Run: SELECT * FROM MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS WHERE STATUS = ''FAIL'' ORDER BY EXECUTED_AT DESC;'
    );

-- =============================================================================
-- SECTION 5: DASHBOARD VIEW — DQ SUMMARY FOR STREAMLIT
-- =============================================================================

CREATE OR REPLACE VIEW MOVIE_PROJECT_DB.DATA_QUALITY.DQ_SUMMARY AS
SELECT
    TEST_CATEGORY,
    COUNT(*) AS TOTAL_TESTS,
    COUNT_IF(STATUS = 'PASS') AS PASSED,
    COUNT_IF(STATUS = 'FAIL') AS FAILED,
    COUNT_IF(STATUS = 'WARN') AS WARNINGS,
    ROUND(COUNT_IF(STATUS = 'PASS') * 100.0 / COUNT(*), 1) AS PASS_RATE
FROM MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
WHERE EXECUTED_AT >= DATEADD('HOUR', -24, CURRENT_TIMESTAMP())
GROUP BY TEST_CATEGORY;

CREATE OR REPLACE VIEW MOVIE_PROJECT_DB.DATA_QUALITY.DQ_RECENT_FAILURES AS
SELECT
    TEST_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    ERROR_DETAIL,
    EXECUTED_AT
FROM MOVIE_PROJECT_DB.DATA_QUALITY.TEST_RESULTS
WHERE STATUS = 'FAIL'
  AND EXECUTED_AT >= DATEADD('HOUR', -24, CURRENT_TIMESTAMP())
ORDER BY EXECUTED_AT DESC;

-- =============================================================================
-- RESUME
-- =============================================================================

ALTER TASK MOVIE_PROJECT_DB.DATA_QUALITY.task_run_dq_tests RESUME;
ALTER ALERT MOVIE_PROJECT_DB.DATA_QUALITY.alert_dq_failure RESUME;
