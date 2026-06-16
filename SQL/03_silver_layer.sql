-- =============================================================================
-- SILVER LAYER VIEWS
-- Database: MOVIE_PROJECT_DB | Schema: SILVER
-- Purpose: Cleaned, typed, deduplicated data from Bronze sources
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS MOVIE_PROJECT_DB.SILVER;

-- -----------------------------------------------------------------------------
-- 1. SILVER.MOVIES_METADATA
-- Source: BRONZE_API_KAGGLE2.MOVIES_METADATA
-- Cleaning: TRY_CAST numeric fields, parse dates, filter invalid IDs
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW MOVIE_PROJECT_DB.SILVER.MOVIES_METADATA AS
SELECT
    TRY_CAST(ID AS NUMBER) AS MOVIE_ID,
    TITLE,
    TRY_CAST(BUDGET AS NUMBER) AS BUDGET,
    TRY_CAST(REVENUE AS NUMBER) AS REVENUE,
    TRY_CAST(POPULARITY AS FLOAT) AS POPULARITY,
    TRY_CAST(VOTE_AVERAGE AS FLOAT) AS VOTE_AVERAGE,
    TRY_CAST(VOTE_COUNT AS NUMBER) AS VOTE_COUNT,
    GENRES,
    PRODUCTION_COMPANIES,
    TRY_CAST(RUNTIME AS NUMBER) AS RUNTIME,
    TRY_TO_DATE(RELEASE_DATE) AS RELEASE_DATE,
    YEAR(TRY_TO_DATE(RELEASE_DATE)) AS RELEASE_YEAR,
    ORIGINAL_LANGUAGE,
    STATUS,
    IMDB_ID
FROM MOVIE_PROJECT_DB.BRONZE_API_KAGGLE2.MOVIES_METADATA
WHERE TRY_CAST(ID AS NUMBER) IS NOT NULL
  AND TITLE IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 2. SILVER.IMDB_MOVIES
-- Source: BRONZE_API_IMDB.TITLE_BASICS + TITLE_RATINGS
-- Cleaning: Join ratings, filter to movies only, min 100 votes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW MOVIE_PROJECT_DB.SILVER.IMDB_MOVIES AS
SELECT
    tb.TCONST,
    tb.PRIMARYTITLE AS TITLE,
    tb.ORIGINALTITLE,
    tb.GENRES,
    tb.STARTYEAR AS RELEASE_YEAR,
    tb.RUNTIMEMINUTES AS RUNTIME,
    tr.AVERAGERATING AS IMDB_RATING,
    tr.NUMVOTES
FROM MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_BASICS tb
JOIN MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_RATINGS tr ON tb.TCONST = tr.TCONST
WHERE tb.TITLETYPE = 'movie'
  AND tb.STARTYEAR IS NOT NULL
  AND tr.NUMVOTES >= 100;

-- -----------------------------------------------------------------------------
-- 3. SILVER.MOVIELENS_MOVIE_RATINGS
-- Source: BRONZE_API_MOVIE_LENS.MOVIES + RATINGS
-- Cleaning: Aggregate ratings per movie, min 50 ratings
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW MOVIE_PROJECT_DB.SILVER.MOVIELENS_MOVIE_RATINGS AS
SELECT
    m.MOVIE_ID,
    m.TITLE,
    m.GENRES,
    AVG(r.RATING) AS AVG_RATING,
    COUNT(r.RATING) AS RATING_COUNT,
    COUNT(DISTINCT r.USER_ID) AS UNIQUE_USERS
FROM MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.MOVIES m
JOIN MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.RATINGS r ON m.MOVIE_ID = r.MOVIE_ID
GROUP BY m.MOVIE_ID, m.TITLE, m.GENRES
HAVING COUNT(r.RATING) >= 50;

-- -----------------------------------------------------------------------------
-- 4. SILVER.NETFLIX_CATALOG
-- Source: BRONZE_API.NETFLIX
-- Cleaning: Parse dates, cast year, rename columns
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW MOVIE_PROJECT_DB.SILVER.NETFLIX_CATALOG AS
SELECT
    SHOW_ID,
    TYPE,
    TITLE,
    DIRECTOR,
    "CAST" AS CAST_MEMBERS,
    COUNTRY,
    TRY_TO_DATE(DATE_ADDED, 'MMMM DD, YYYY') AS DATE_ADDED,
    YEAR(TRY_TO_DATE(DATE_ADDED, 'MMMM DD, YYYY')) AS ADDED_YEAR,
    TRY_CAST(RELEASE_YEAR AS NUMBER) AS RELEASE_YEAR,
    RATING AS MATURITY_RATING,
    DURATION,
    LISTED_IN AS GENRE,
    DESCRIPTION
FROM MOVIE_PROJECT_DB.BRONZE_API.NETFLIX
WHERE TITLE IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 5. SILVER.MOVIELENS_USER_RATINGS
-- Source: BRONZE_API_MOVIE_LENS.RATINGS + MOVIES
-- Cleaning: Convert timestamps to dates, join movie info
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW MOVIE_PROJECT_DB.SILVER.MOVIELENS_USER_RATINGS AS
SELECT
    r.USER_ID,
    r.MOVIE_ID,
    r.RATING,
    TO_DATE(TO_TIMESTAMP(r.RATING_TIMESTAMP)) AS RATING_DATE,
    YEAR(TO_DATE(TO_TIMESTAMP(r.RATING_TIMESTAMP))) AS RATING_YEAR,
    MONTH(TO_DATE(TO_TIMESTAMP(r.RATING_TIMESTAMP))) AS RATING_MONTH,
    m.TITLE,
    m.GENRES
FROM MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.RATINGS r
JOIN MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.MOVIES m ON r.MOVIE_ID = m.MOVIE_ID
WHERE r.RATING_TIMESTAMP > 0;

-- -----------------------------------------------------------------------------
-- 6. SILVER.MOVIELENS_TAGS
-- Source: BRONZE_API_MOVIE_LENS.TAGS + MOVIES
-- Cleaning: Convert timestamps, join movie info, filter nulls
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW MOVIE_PROJECT_DB.SILVER.MOVIELENS_TAGS AS
SELECT
    t.USER_ID,
    t.MOVIE_ID,
    t.TAG,
    TO_DATE(TO_TIMESTAMP(t.TAG_TIMESTAMP)) AS TAG_DATE,
    m.TITLE,
    m.GENRES
FROM MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.TAGS t
JOIN MOVIE_PROJECT_DB.BRONZE_API_MOVIE_LENS.MOVIES m ON t.MOVIE_ID = m.MOVIE_ID
WHERE t.TAG IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 7. SILVER.IMDB_CAST_CREW
-- Source: BRONZE_API_IMDB.TITLE_PRINCIPALS + NAME_BASICS + TITLE_BASICS + TITLE_RATINGS
-- Cleaning: Join all sources, filter to movies with 1000+ votes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW MOVIE_PROJECT_DB.SILVER.IMDB_CAST_CREW AS
SELECT
    tp.TCONST,
    tp.NCONST,
    tp.CATEGORY,
    tp.JOB,
    tp.CHARACTERS,
    nb.PRIMARYNAME,
    tb.PRIMARYTITLE AS TITLE,
    tb.STARTYEAR AS RELEASE_YEAR,
    tr.AVERAGERATING AS IMDB_RATING,
    tr.NUMVOTES
FROM MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_PRINCIPALS tp
JOIN MOVIE_PROJECT_DB.BRONZE_API_IMDB.NAME_BASICS nb ON tp.NCONST = nb.NCONST
JOIN MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_BASICS tb ON tp.TCONST = tb.TCONST
JOIN MOVIE_PROJECT_DB.BRONZE_API_IMDB.TITLE_RATINGS tr ON tp.TCONST = tr.TCONST
WHERE tb.TITLETYPE = 'movie'
  AND tr.NUMVOTES >= 1000
  AND tp.CATEGORY IN ('actor', 'actress', 'director');
