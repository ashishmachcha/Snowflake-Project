-- =============================================================================
-- REAL-TIME INGESTION LAYER
-- Database: MOVIE_PROJECT_DB
-- Purpose: Snowpipe (auto-ingest from S3), Snowpipe Streaming setup,
--          and event-driven ingestion for continuous data flow
-- Depends on: bronze_layer.sql (stages and tables must exist)
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- =============================================================================
-- SECTION 1: SNOWPIPE — AUTO-INGEST FROM S3 (Near Real-Time, ~1-2 min latency)
-- Triggered by S3 event notifications (SQS) when new files land in bucket
-- =============================================================================

-- ---------- IMDB Data (from s3://<YOUR_IMDB_BUCKET>/S3/) ----------

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_title_basics
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_BASICS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_IMDB.s3_stage
  PATTERN = '.*title.basics.*'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_title_ratings
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_RATINGS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_IMDB.s3_stage
  PATTERN = '.*title.ratings.*'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_title_crew
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_CREW
  FROM @MOVIE_PROJECT_DB.BRONZE_API_IMDB.s3_stage
  PATTERN = '.*title.crew.*'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_title_episode
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_EPISODE
  FROM @MOVIE_PROJECT_DB.BRONZE_API_IMDB.s3_stage
  PATTERN = '.*title.episode.*'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_title_principals
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_PRINCIPALS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_IMDB.s3_stage
  PATTERN = '.*title.principals.*'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_title_akas
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_AKAS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_IMDB.s3_stage
  PATTERN = '.*title.akas.*'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_name_basics
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_IMDB.NAME_BASICS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_IMDB.s3_stage
  PATTERN = '.*name.basics.*'
  ON_ERROR = 'SKIP_FILE';

-- ---------- Kaggle Data (from s3://<YOUR_KAGGLE_BUCKET>/archive/) ----------

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.pipe_movies_metadata
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.MOVIES_METADATA
  FROM @MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.s3_stage
  PATTERN = '.*movies_metadata.*'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.pipe_credits
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.CREDITS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.s3_stage
  PATTERN = '.*credits.*'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.pipe_keywords
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.KEYWORDS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.s3_stage
  PATTERN = '.*keywords.*'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.pipe_ratings
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.RATINGS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.s3_stage
  PATTERN = '.*ratings.csv'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.pipe_links
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.LINKS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.s3_stage
  PATTERN = '.*links.csv'
  ON_ERROR = 'SKIP_FILE';

-- ---------- MovieLens Data (from s3://<YOUR_MOVIELENS_BUCKET>/ml-32m/) ----------

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.pipe_movies
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.MOVIES
  FROM @MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.s3_stage
  PATTERN = '.*movies.csv'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.pipe_ratings
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.RATINGS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.s3_stage
  PATTERN = '.*ratings.csv'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.pipe_tags
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.TAGS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.s3_stage
  PATTERN = '.*tags.csv'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.pipe_genome_scores
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.GENOME_SCORES
  FROM @MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.s3_stage
  PATTERN = '.*genome-scores.csv'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.pipe_genome_tags
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.GENOME_TAGS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.s3_stage
  PATTERN = '.*genome-tags.csv'
  ON_ERROR = 'SKIP_FILE';

CREATE OR REPLACE PIPE MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.pipe_links
  AUTO_INGEST = TRUE
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.LINKS
  FROM @MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.s3_stage
  PATTERN = '.*links.csv'
  ON_ERROR = 'SKIP_FILE';

-- =============================================================================
-- SECTION 2: SNOWPIPE STATUS & MONITORING QUERIES
-- =============================================================================

-- Check pipe status (run manually to verify)
-- SELECT SYSTEM$PIPE_STATUS('MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_title_basics');

-- Check recent pipe load history
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
--   TABLE_NAME => 'MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_BASICS',
--   START_TIME => DATEADD('HOUR', -24, CURRENT_TIMESTAMP())
-- ));

-- =============================================================================
-- SECTION 3: INTERNAL STAGE LOADERS (for manual/batch file uploads via UI)
-- These tasks poll internal upload stages every 5 min for manually uploaded files
-- =============================================================================

CREATE OR REPLACE TASK MOVIE_PROJECT_DB.PUBLIC.task_load_internal_netflix
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Loads Netflix CSV files uploaded manually to internal stage'
AS
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API.NETFLIX
  FROM @MOVIE_PROJECT_DB.BRONZE_API.upload_stage/netflix/
  ON_ERROR = 'CONTINUE'
  PURGE = TRUE;

CREATE OR REPLACE TASK MOVIE_PROJECT_DB.PUBLIC.task_load_internal_imdb
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Loads IMDB TSV files uploaded manually to internal stage'
AS
BEGIN
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_BASICS
    FROM @MOVIE_PROJECT_DB.BRONZE_API_IMDB.upload_stage/title_basics/
    ON_ERROR = 'CONTINUE' PURGE = TRUE;
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_RATINGS
    FROM @MOVIE_PROJECT_DB.BRONZE_API_IMDB.upload_stage/title_ratings/
    ON_ERROR = 'CONTINUE' PURGE = TRUE;
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_PRINCIPALS
    FROM @MOVIE_PROJECT_DB.BRONZE_API_IMDB.upload_stage/title_principals/
    ON_ERROR = 'CONTINUE' PURGE = TRUE;
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_IMDB.NAME_BASICS
    FROM @MOVIE_PROJECT_DB.BRONZE_API_IMDB.upload_stage/name_basics/
    ON_ERROR = 'CONTINUE' PURGE = TRUE;
END;

CREATE OR REPLACE TASK MOVIE_PROJECT_DB.PUBLIC.task_load_internal_kaggle
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Loads Kaggle CSV files uploaded manually to internal stage'
AS
BEGIN
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.MOVIES_METADATA
    FROM @MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.upload_stage/movies_metadata/
    ON_ERROR = 'CONTINUE' PURGE = TRUE;
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.CREDITS
    FROM @MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.upload_stage/credits/
    ON_ERROR = 'CONTINUE' PURGE = TRUE;
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.RATINGS
    FROM @MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.upload_stage/ratings/
    ON_ERROR = 'CONTINUE' PURGE = TRUE;
END;

CREATE OR REPLACE TASK MOVIE_PROJECT_DB.PUBLIC.task_load_internal_movielens
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Loads MovieLens CSV files uploaded manually to internal stage'
AS
BEGIN
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.MOVIES
    FROM @MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.upload_stage/movies/
    ON_ERROR = 'CONTINUE' PURGE = TRUE;
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.RATINGS
    FROM @MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.upload_stage/ratings/
    ON_ERROR = 'CONTINUE' PURGE = TRUE;
  COPY INTO MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.TAGS
    FROM @MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.upload_stage/tags/
    ON_ERROR = 'CONTINUE' PURGE = TRUE;
END;

-- =============================================================================
-- SECTION 4: S3 EVENT NOTIFICATION SETUP (reference for AWS side)
-- =============================================================================
-- To enable AUTO_INGEST, configure S3 Event Notifications → SQS:
--
-- 1. Get the SQS ARN for each pipe:
--    SELECT SYSTEM$PIPE_STATUS('MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_title_basics');
--    → Copy "notificationChannelName" value
--
-- 2. In AWS Console → S3 Bucket → Properties → Event Notifications:
--    - Event type: s3:ObjectCreated:*
--    - Destination: SQS queue (paste the ARN from step 1)
--    - Prefix filter: match the pipe pattern (e.g., "S3/title.basics")
--
-- 3. Verify connection:
--    SELECT SYSTEM$PIPE_STATUS('MOVIE_PROJECT_DB.BRONZE_API_IMDB.pipe_title_basics');
--    → "executionState" should be "RUNNING"
-- =============================================================================

-- =============================================================================
-- SECTION 5: PIPE INGESTION LOG TABLE (tracks what files were loaded)
-- =============================================================================

CREATE TABLE IF NOT EXISTS MOVIE_PROJECT_DB.PUBLIC.PIPE_INGESTION_LOG (
    LOG_ID NUMBER AUTOINCREMENT,
    PIPE_NAME VARCHAR,
    FILE_NAME VARCHAR,
    FILE_SIZE NUMBER,
    ROW_COUNT NUMBER,
    STATUS VARCHAR,           -- SUCCESS, PARTIAL, FAILED
    ERROR_MESSAGE VARCHAR,
    INGESTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- =============================================================================
-- VERIFY PIPES
-- =============================================================================
SHOW PIPES IN DATABASE MOVIE_PROJECT_DB;
