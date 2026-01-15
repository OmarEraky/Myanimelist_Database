-- =========================================================
-- MyAnimeList DB (UPDATED per Prof. Tuğba notes)
-- Changes applied:
-- ✅ Author split into first_name / last_name (+ display_name for messy cases)
-- ✅ Remove japanese/english/german/french/spanish columns from Entry
-- ✅ Add Language + LanguageEntry (M:N with Entry) and store title_text there
-- ✅ Split anime dates: airing (from/to), broadcast (day/time/tz), premier (season/year)
-- ✅ Split manga publishing date: from/to
-- ✅ Synonyms: separate Synonym + EntrySynonym (split list values during preparation)
-- =========================================================
CREATE DATABASE IF NOT EXISTS myanimelist_db_v2;
USE myanimelist_db_v2;
SET FOREIGN_KEY_CHECKS = 0;
-- Drop relationship tables first
DROP TABLE IF EXISTS EntrySynonym;
DROP TABLE IF EXISTS LanguageEntry;
DROP TABLE IF EXISTS EntrySerialization;
DROP TABLE IF EXISTS EntryAuthor;
DROP TABLE IF EXISTS EntryStudio;
DROP TABLE IF EXISTS EntryLicensor;
DROP TABLE IF EXISTS EntryProducer;
DROP TABLE IF EXISTS EntryTheme;
DROP TABLE IF EXISTS EntryGenre;
DROP TABLE IF EXISTS EntryDemographic;  -- NEW: Added for many-to-many
-- Drop subtype tables
DROP TABLE IF EXISTS AnimeDetails;
DROP TABLE IF EXISTS MangaDetails;
-- Drop entity tables
DROP TABLE IF EXISTS Synonym;
DROP TABLE IF EXISTS Language;
DROP TABLE IF EXISTS Serialization;
DROP TABLE IF EXISTS Author;
DROP TABLE IF EXISTS Studio;
DROP TABLE IF EXISTS Licensor;
DROP TABLE IF EXISTS Producer;
DROP TABLE IF EXISTS Theme;
DROP TABLE IF EXISTS Genre;
-- Drop core + lookups
DROP TABLE IF EXISTS Entry;
DROP TABLE IF EXISTS StatusType;
DROP TABLE IF EXISTS AgeRating;
DROP TABLE IF EXISTS Source;
DROP TABLE IF EXISTS Demographic;
DROP TABLE IF EXISTS ItemType;
SET FOREIGN_KEY_CHECKS = 1;
-- =========================================================
-- Lookup / dimension tables
-- =========================================================
CREATE TABLE Medium (
    medium_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL, -- 'anime', 'manga'
    UNIQUE KEY uq_medium_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ItemType (
    item_type_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medium_id INT UNSIGNED NOT NULL,
    type_name VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_itemtype_medium_type_name (medium_id, type_name),
    CONSTRAINT fk_itemtype_medium
        FOREIGN KEY (medium_id)
        REFERENCES Medium (medium_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE Demographic (
    demographic_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_demographic_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE Source (
    source_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    source_name VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_source_name (source_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE AgeRating (
    age_rating_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(10) NOT NULL, -- 'G', 'PG', 'PG-13', 'R', 'Rx'
    description VARCHAR(255),
    UNIQUE KEY uq_agerating_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE StatusType (
    status_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    status_name VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_status_name (status_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- =========================================================
-- Core Entry table (supertype)
-- NOTE: language-specific names and synonymns REMOVED per edits
-- NOTE: Removed demographic_id to enable many-to-many
-- =========================================================
CREATE TABLE Entry (
    entry_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    mal_id INT UNSIGNED NOT NULL, -- original dataset id
    -- medium_type REMOVED for 3NF (transitive dependency via item_type_id)
    link VARCHAR(500),
    title_name TEXT NOT NULL, -- main/original display title
    score DECIMAL(4,2),
    scored_by INT UNSIGNED,
    ranked INT UNSIGNED,
    popularity INT UNSIGNED,
    members INT UNSIGNED,
    favorited INT UNSIGNED,
    item_type_id INT UNSIGNED,
    description TEXT,
    background TEXT,
    CONSTRAINT uq_entry_mal_id_item UNIQUE (mal_id, item_type_id),
    CONSTRAINT fk_entry_item_type
        FOREIGN KEY (item_type_id)
        REFERENCES ItemType (item_type_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE INDEX idx_entry_score ON Entry (score);
CREATE INDEX idx_entry_popularity ON Entry (popularity);
CREATE INDEX idx_entry_members ON Entry (members);
-- =========================================================
-- Language + relationship table storing title text
-- (Prof note: language table + many-to-many with Entry + relationship table)
-- (If a language title is NULL in raw data → DO NOT insert into LanguageEntry)
-- =========================================================
CREATE TABLE Language (
    language_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    language_name VARCHAR(50) NOT NULL,
    UNIQUE KEY uq_language_name (language_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE LanguageEntry (
    entry_id INT UNSIGNED NOT NULL,
    language_id INT UNSIGNED NOT NULL,
    title_text TEXT NOT NULL, -- stores the actual localized title text
    PRIMARY KEY (entry_id, language_id),
    CONSTRAINT fk_languageentry_entry
        FOREIGN KEY (entry_id)
        REFERENCES Entry (entry_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_languageentry_language
        FOREIGN KEY (language_id)
        REFERENCES Language (language_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- =========================================================
-- Anime and Manga subtype tables (1:1 with Entry)
-- Dates split per Prof note
-- =========================================================
CREATE TABLE AnimeDetails (
    entry_id INT UNSIGNED PRIMARY KEY,
    episodes INT UNSIGNED,
    status_id INT UNSIGNED,
    -- split airing_date into from/to
    from_airing_date DATE NULL,
    to_airing_date DATE NULL,
    -- split premier_date into season/year
    premier_date_season ENUM('Winter','Spring','Summer','Fall') NULL,
    premier_date_year SMALLINT UNSIGNED NULL,
    -- split broadcast_date into day/time/timezone
    broadcast_date_day VARCHAR(20) NULL, -- e.g. 'Mondays'
    broadcast_date_time TIME NULL, -- e.g. '22:00:00'
    broadcast_date_timezone VARCHAR(20) NULL, -- e.g. 'JST'
    duration_minutes INT UNSIGNED, -- Normalized duration
    age_rating_id INT UNSIGNED,
    source_id INT UNSIGNED,
    CONSTRAINT fk_anime_entry
        FOREIGN KEY (entry_id)
        REFERENCES Entry (entry_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_anime_status
        FOREIGN KEY (status_id)
        REFERENCES StatusType (status_id),
    CONSTRAINT fk_anime_age_rating
        FOREIGN KEY (age_rating_id)
        REFERENCES AgeRating (age_rating_id),
    CONSTRAINT fk_anime_source
        FOREIGN KEY (source_id)
        REFERENCES Source (source_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE MangaDetails (
    entry_id INT UNSIGNED PRIMARY KEY,
    volumes INT UNSIGNED,
    chapters INT UNSIGNED,
    status_id INT UNSIGNED,
    -- split publishing_date into from/to
    from_publishing_date DATE NULL,
    to_publishing_date DATE NULL,
    CONSTRAINT fk_manga_entry
        FOREIGN KEY (entry_id)
        REFERENCES Entry (entry_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_manga_status
        FOREIGN KEY (status_id)
        REFERENCES StatusType (status_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- NEW: Duration split into own table per request (REMOVED per subsequent request)
-- CREATE TABLE Entry_Duration ...
-- =========================================================
-- Genre / Theme (many-to-many)
-- =========================================================
CREATE TABLE Genre (
    genre_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_genre_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE EntryGenre (
    entry_id INT UNSIGNED NOT NULL,
    genre_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (entry_id, genre_id),
    CONSTRAINT fk_entrygenre_entry
        FOREIGN KEY (entry_id)
        REFERENCES Entry (entry_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_entrygenre_genre
        FOREIGN KEY (genre_id)
        REFERENCES Genre (genre_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE Theme (
    theme_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_theme_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE EntryTheme (
    entry_id INT UNSIGNED NOT NULL,
    theme_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (entry_id, theme_id),
    CONSTRAINT fk_entrytheme_entry
        FOREIGN KEY (entry_id)
        REFERENCES Entry (entry_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_entrytheme_theme
        FOREIGN KEY (theme_id)
        REFERENCES Theme (theme_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- =========================================================
-- NEW: Many-to-many for Entry and Demographic
-- =========================================================
CREATE TABLE EntryDemographic (
    entry_id INT UNSIGNED NOT NULL,
    demographic_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (entry_id, demographic_id),
    CONSTRAINT fk_entrydemographic_entry
        FOREIGN KEY (entry_id)
        REFERENCES Entry (entry_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_entrydemographic_demographic
        FOREIGN KEY (demographic_id)
        REFERENCES Demographic (demographic_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- =========================================================
-- Production-related entities (anime)
-- =========================================================
CREATE TABLE Producer (
    producer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    UNIQUE KEY uq_producer_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE EntryProducer (
    entry_id INT UNSIGNED NOT NULL,
    producer_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (entry_id, producer_id),
    CONSTRAINT fk_entryproducer_entry
        FOREIGN KEY (entry_id)
        REFERENCES Entry (entry_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_entryproducer_producer
        FOREIGN KEY (producer_id)
        REFERENCES Producer (producer_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE Licensor (
    licensor_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    UNIQUE KEY uq_licensor_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE EntryLicensor (
    entry_id INT UNSIGNED NOT NULL,
    licensor_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (entry_id, licensor_id),
    CONSTRAINT fk_entrylicensor_entry
        FOREIGN KEY (entry_id)
        REFERENCES Entry (entry_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_entrylicensor_licensor
        FOREIGN KEY (licensor_id)
        REFERENCES Licensor (licensor_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE Studio (
    studio_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    UNIQUE KEY uq_studio_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE EntryStudio (
    entry_id INT UNSIGNED NOT NULL,
    studio_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (entry_id, studio_id),
    CONSTRAINT fk_entrystudio_entry
        FOREIGN KEY (entry_id)
        REFERENCES Entry (entry_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_entrystudio_studio
        FOREIGN KEY (studio_id)
        REFERENCES Studio (studio_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- =========================================================
-- Authors & Serialization (manga)
-- Author split per Prof note.
-- display_name keeps raw/original when first/last can't be parsed cleanly.
-- =========================================================
CREATE TABLE Author (
    author_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(150),
    last_name VARCHAR(150),
    -- display_name REMOVED
    UNIQUE KEY uq_author_name (first_name, last_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE EntryAuthor (
    entry_id INT UNSIGNED NOT NULL,
    author_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (entry_id, author_id),
    CONSTRAINT fk_entryauthor_entry
        FOREIGN KEY (entry_id)
        REFERENCES Entry (entry_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_entryauthor_author
        FOREIGN KEY (author_id)
        REFERENCES Author (author_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE Serialization (
    serialization_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    UNIQUE KEY uq_serialization_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE EntrySerialization (
    entry_id INT UNSIGNED NOT NULL,
    serialization_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (entry_id, serialization_id),
    CONSTRAINT fk_entryserialization_entry
        FOREIGN KEY (entry_id)
        REFERENCES Entry (entry_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_entryserialization_serialization
        FOREIGN KEY (serialization_id)
        REFERENCES Serialization (serialization_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- =========================================================
-- Synonyms (Option B chosen): Synonym + EntrySynonym
-- During preparation, split comma/list values into separate synonym_text rows.
-- =========================================================
CREATE TABLE Synonym (
    synonym_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    synonym_text VARCHAR(255) NOT NULL,
    UNIQUE KEY uq_synonym_text (synonym_text)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE EntrySynonym (
    entry_id INT UNSIGNED NOT NULL,
    synonym_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (entry_id, synonym_id),
    CONSTRAINT fk_entrysynonym_entry
        FOREIGN KEY (entry_id)
        REFERENCES Entry (entry_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_entrysynonym_synonym
        FOREIGN KEY (synonym_id)
        REFERENCES Synonym (synonym_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- =========================================================
-- Done
-- =========================================================