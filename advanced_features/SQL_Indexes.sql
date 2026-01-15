-- =========================================================
-- Indexes
-- =========================================================

USE myanimelist_db_v2;

-- -----------------------------------------------------------------------------
-- 1. Index on Entry Title
-- Reason: Essential for search functionality (Partial string matching).
-- -----------------------------------------------------------------------------
-- Dropping first to avoid errors if re-running
DROP INDEX idx_entry_title_prefix ON Entry;
CREATE INDEX idx_entry_title_prefix ON Entry (title_name(50));

-- -----------------------------------------------------------------------------
-- 2. Index on Anime Premier Year
-- Reason: Very common filter ("best anime of 2023").
-- -----------------------------------------------------------------------------
DROP INDEX idx_anime_year ON AnimeDetails;
CREATE INDEX idx_anime_year ON AnimeDetails (premier_date_year);

-- -----------------------------------------------------------------------------
-- 3. Index on Lookup Names (Genre)
-- Reason: Lookup tables are joined often. Indexing name speeds up "Give me Action anime" queries.
-- -----------------------------------------------------------------------------
DROP INDEX idx_genre_name ON Genre;
CREATE INDEX idx_genre_name ON Genre (name);

-- -----------------------------------------------------------------------------
-- 4. Index on Studio Name
-- Reason: Optimizes "View_StudioPerformance" and studio-based searches.
-- -----------------------------------------------------------------------------
DROP INDEX idx_studio_name ON Studio;
CREATE INDEX idx_studio_name ON Studio (name);

-- -----------------------------------------------------------------------------
-- 5. Composite Index on Entry (Type + Score)
-- Reason: Optimizes queries like "Show me the top rated TV Series".
-- Used when filtering by Item Type AND sorting by Score.
-- -----------------------------------------------------------------------------
DROP INDEX idx_entry_type_score ON Entry;
CREATE INDEX idx_entry_type_score ON Entry (item_type_id, score);

-- -----------------------------------------------------------------------------
-- 6. Index on ItemType Name
-- Reason: Optimizes filtering by type (e.g., "All Movies") regardless of Medium.
-- -----------------------------------------------------------------------------
DROP INDEX idx_itemtype_name ON ItemType;
CREATE INDEX idx_itemtype_name ON ItemType (type_name);
