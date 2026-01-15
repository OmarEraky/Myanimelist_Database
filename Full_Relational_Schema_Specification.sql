-- =======================================================================================
-- FULL RELATIONAL TABLE SPECIFICATION
-- Database: myanimelist_db_v2
-- Description: 
-- This file contains the complete Data Definition Language (DDL) for the MyAnimeList database.
-- Each attribute includes its data type, constraints (NOT NULL, PRIMARY KEY, FOREIGN KEY),
-- and a sample data value provided as a comment (e.g., -- val: 'Sample').
-- =======================================================================================

-- ---------------------------------------------------------------------------------------
-- 1. Lookup Tables
-- ---------------------------------------------------------------------------------------

CREATE TABLE ItemType (
    item_type_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 1
    medium_type ENUM('anime', 'manga') NOT NULL,          -- val: 'anime'
    type_name VARCHAR(100) NOT NULL,                      -- val: 'TV'
    UNIQUE KEY uq_itemtype_medium_type_name (medium_type, type_name)
);

CREATE TABLE Demographic (
    demographic_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 5
    name VARCHAR(100) NOT NULL,                             -- val: 'Shounen'
    UNIQUE KEY uq_demographic_name (name)
);

CREATE TABLE Source (
    source_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 2
    source_name VARCHAR(100) NOT NULL,                 -- val: 'Manga'
    UNIQUE KEY uq_source_name (source_name)
);

CREATE TABLE AgeRating (
    age_rating_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 3
    code VARCHAR(10) NOT NULL,                             -- val: 'PG-13'
    description VARCHAR(255),                              -- val: 'Teens 13 or older'
    UNIQUE KEY uq_agerating_code (code)
);

CREATE TABLE StatusType (
    status_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 1
    status_name VARCHAR(100) NOT NULL,                 -- val: 'Finished Airing'
    UNIQUE KEY uq_status_name (status_name)
);

-- ---------------------------------------------------------------------------------------
-- 2. Core Entity: Entry
-- ---------------------------------------------------------------------------------------

CREATE TABLE Entry (
    entry_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 5114
    mal_id INT UNSIGNED NOT NULL,                     -- val: 5114 (Fullmetal Alchemist: Brotherhood)
    link VARCHAR(500),                                -- val: 'https://myanimelist.net/anime/5114/...'
    title_name TEXT NOT NULL,                         -- val: 'Fullmetal Alchemist: Brotherhood'
    score DECIMAL(4,2),                               -- val: 9.10
    scored_by INT UNSIGNED,                           -- val: 1876543
    ranked INT UNSIGNED,                              -- val: 1
    popularity INT UNSIGNED,                          -- val: 3
    members INT UNSIGNED,                             -- val: 2932347
    favorited INT UNSIGNED,                           -- val: 204645
    item_type_id INT UNSIGNED,                        -- val: 1
    description TEXT,                                 -- val: 'After a horrific alchemy experiment...'
    background TEXT,                                  -- val: 'Production by Bones...'
    CONSTRAINT uq_entry_mal_id_item UNIQUE (mal_id, item_type_id),
    CONSTRAINT fk_entry_item_type FOREIGN KEY (item_type_id) REFERENCES ItemType (item_type_id)
);

-- ---------------------------------------------------------------------------------------
-- 3. Language & Localization
-- ---------------------------------------------------------------------------------------

CREATE TABLE Language (
    language_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 1
    language_name VARCHAR(50) NOT NULL,                  -- val: 'Japanese'
    UNIQUE KEY uq_language_name (language_name)
);

CREATE TABLE LanguageEntry (
    entry_id INT UNSIGNED NOT NULL,    -- val: 5114
    language_id INT UNSIGNED NOT NULL, -- val: 1
    title_text TEXT NOT NULL,          -- val: 'Hagane no Renkinjutsushi: Fullmetal Alchemist'
    PRIMARY KEY (entry_id, language_id),
    CONSTRAINT fk_languageentry_entry FOREIGN KEY (entry_id) REFERENCES Entry (entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_languageentry_language FOREIGN KEY (language_id) REFERENCES Language (language_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------------------
-- 4. Subtypes: Anime & Manga Details
-- ---------------------------------------------------------------------------------------

CREATE TABLE AnimeDetails (
    entry_id INT UNSIGNED PRIMARY KEY,            -- val: 5114
    episodes INT UNSIGNED,                        -- val: 64
    status_id INT UNSIGNED,                       -- val: 1
    from_airing_date DATE NULL,                   -- val: '2009-04-05'
    to_airing_date DATE NULL,                     -- val: '2010-07-04'
    premier_date_season ENUM('Winter','Spring','Summer','Fall') NULL, -- val: 'Spring'
    premier_date_year SMALLINT UNSIGNED NULL,     -- val: 2009
    broadcast_date_day VARCHAR(20), -- val: 'Fridays'
    broadcast_date_time TIME, -- val: '23:00:00'
    broadcast_date_timezone VARCHAR(20), -- val: 'JST'
    duration_minutes INT UNSIGNED, -- val: 24
    age_rating_id INT UNSIGNED, -- val: 1 (PG-13)
    source_id INT UNSIGNED, -- val: 1 (Manga)
    CONSTRAINT fk_anime_entry FOREIGN KEY (entry_id) REFERENCES Entry (entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_anime_status FOREIGN KEY (status_id) REFERENCES StatusType (status_id),
    CONSTRAINT fk_anime_age_rating FOREIGN KEY (age_rating_id) REFERENCES AgeRating (age_rating_id),
    CONSTRAINT fk_anime_source FOREIGN KEY (source_id) REFERENCES Source (source_id)
);

CREATE TABLE MangaDetails (
    entry_id INT UNSIGNED PRIMARY KEY,            -- val: 2
    volumes INT UNSIGNED,                         -- val: 18
    chapters INT UNSIGNED,                        -- val: 139
    status_id INT UNSIGNED,                       -- val: 1
    from_publishing_date DATE NULL,               -- val: '2003-12-16'
    to_publishing_date DATE NULL,                 -- val: '2010-06-15'
    CONSTRAINT fk_manga_entry FOREIGN KEY (entry_id) REFERENCES Entry (entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_manga_status FOREIGN KEY (status_id) REFERENCES StatusType (status_id)
);

-- ---------------------------------------------------------------------------------------
-- 5. New Features
-- ---------------------------------------------------------------------------------------

-- (Entry_Duration removed for 3NF simplicity per request)

-- ---------------------------------------------------------------------------------------
-- 6. Many-to-Many Relationships
-- ---------------------------------------------------------------------------------------

CREATE TABLE Genre (
    genre_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 1
    name VARCHAR(100) NOT NULL,                       -- val: 'Action'
    UNIQUE KEY uq_genre_name (name)
);

CREATE TABLE EntryGenre (
    entry_id INT UNSIGNED NOT NULL,  -- val: 5114
    genre_id INT UNSIGNED NOT NULL,  -- val: 1
    PRIMARY KEY (entry_id, genre_id),
    CONSTRAINT fk_entrygenre_entry FOREIGN KEY (entry_id) REFERENCES Entry (entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_entrygenre_genre FOREIGN KEY (genre_id) REFERENCES Genre (genre_id) ON DELETE CASCADE
);

CREATE TABLE Theme (
    theme_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 10
    name VARCHAR(100) NOT NULL,                       -- val: 'Military'
    UNIQUE KEY uq_theme_name (name)
);

CREATE TABLE EntryTheme (
    entry_id INT UNSIGNED NOT NULL,  -- val: 5114
    theme_id INT UNSIGNED NOT NULL,  -- val: 10
    PRIMARY KEY (entry_id, theme_id),
    CONSTRAINT fk_entrytheme_entry FOREIGN KEY (entry_id) REFERENCES Entry (entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_entrytheme_theme FOREIGN KEY (theme_id) REFERENCES Theme (theme_id) ON DELETE CASCADE
);

CREATE TABLE EntryDemographic (
    entry_id INT UNSIGNED NOT NULL,       -- val: 5114
    demographic_id INT UNSIGNED NOT NULL, -- val: 5
    PRIMARY KEY (entry_id, demographic_id),
    CONSTRAINT fk_entrydemographic_entry FOREIGN KEY (entry_id) REFERENCES Entry (entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_entrydemographic_demographic FOREIGN KEY (demographic_id) REFERENCES Demographic (demographic_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------------------
-- 7. Production Entities
-- ---------------------------------------------------------------------------------------

CREATE TABLE Producer (
    producer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 100
    name VARCHAR(255) NOT NULL,                          -- val: 'Aniplex'
    UNIQUE KEY uq_producer_name (name)
);

CREATE TABLE EntryProducer (
    entry_id INT UNSIGNED NOT NULL,     -- val: 5114
    producer_id INT UNSIGNED NOT NULL,  -- val: 100
    PRIMARY KEY (entry_id, producer_id),
    CONSTRAINT fk_entryproducer_entry FOREIGN KEY (entry_id) REFERENCES Entry (entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_entryproducer_producer FOREIGN KEY (producer_id) REFERENCES Producer (producer_id) ON DELETE CASCADE
);

CREATE TABLE Licensor (
    licensor_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 50
    name VARCHAR(255) NOT NULL,                          -- val: 'Funimation'
    UNIQUE KEY uq_licensor_name (name)
);

CREATE TABLE EntryLicensor (
    entry_id INT UNSIGNED NOT NULL,    -- val: 5114
    licensor_id INT UNSIGNED NOT NULL, -- val: 50
    PRIMARY KEY (entry_id, licensor_id),
    CONSTRAINT fk_entrylicensor_entry FOREIGN KEY (entry_id) REFERENCES Entry (entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_entrylicensor_licensor FOREIGN KEY (licensor_id) REFERENCES Licensor (licensor_id) ON DELETE CASCADE
);

CREATE TABLE Studio (
    studio_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 10
    name VARCHAR(255) NOT NULL,                        -- val: 'Bones'
    UNIQUE KEY uq_studio_name (name)
);

CREATE TABLE EntryStudio (
    entry_id INT UNSIGNED NOT NULL,    -- val: 5114
    studio_id INT UNSIGNED NOT NULL,   -- val: 10
    PRIMARY KEY (entry_id, studio_id),
    CONSTRAINT fk_entrystudio_entry FOREIGN KEY (entry_id) REFERENCES Entry (entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_entrystudio_studio FOREIGN KEY (studio_id) REFERENCES Studio (studio_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------------------
-- 8. Authors & Serializations
-- ---------------------------------------------------------------------------------------

CREATE TABLE Author (
    author_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 301
    first_name VARCHAR(150),                           -- val: 'Hiromu'
    last_name VARCHAR(150),                            -- val: 'Arakawa'
    UNIQUE KEY uq_author_name (first_name, last_name)
);

CREATE TABLE EntryAuthor (
    entry_id INT UNSIGNED NOT NULL,    -- val: 2
    author_id INT UNSIGNED NOT NULL,   -- val: 301
    PRIMARY KEY (entry_id, author_id),
    CONSTRAINT fk_entryauthor_entry FOREIGN KEY (entry_id) REFERENCES Entry (entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_entryauthor_author FOREIGN KEY (author_id) REFERENCES Author (author_id) ON DELETE CASCADE
);

CREATE TABLE Serialization (
    serialization_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 20
    name VARCHAR(255) NOT NULL,                               -- val: 'Shonen Gangan'
    UNIQUE KEY uq_serialization_name (name)
);

CREATE TABLE EntrySerialization (
    entry_id INT UNSIGNED NOT NULL,            -- val: 2
    serialization_id INT UNSIGNED NOT NULL,    -- val: 20
    PRIMARY KEY (entry_id, serialization_id),
    CONSTRAINT fk_entryserialization_entry FOREIGN KEY (entry_id) REFERENCES Entry (entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_entryserialization_serialization FOREIGN KEY (serialization_id) REFERENCES Serialization (serialization_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------------------
-- 9. Synonyms
-- ---------------------------------------------------------------------------------------

CREATE TABLE Synonym (
    synonym_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, -- val: 500
    synonym_text VARCHAR(255) NOT NULL,                 -- val: 'FMAB'
    UNIQUE KEY uq_synonym_text (synonym_text)
);

CREATE TABLE EntrySynonym (
    entry_id INT UNSIGNED NOT NULL,    -- val: 5114
    synonym_id INT UNSIGNED NOT NULL,  -- val: 500
    PRIMARY KEY (entry_id, synonym_id),
    CONSTRAINT fk_entrysynonym_entry FOREIGN KEY (entry_id) REFERENCES Entry (entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_entrysynonym_synonym FOREIGN KEY (synonym_id) REFERENCES Synonym (synonym_id) ON DELETE CASCADE
);
