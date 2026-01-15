-- =========================================================
-- Stored Procedures (Updated for Strict 3NF Schema v2)
-- =========================================================

USE myanimelist_db_v2;

DELIMITER //

-- -----------------------------------------------------------------------------
-- 1. GetGenreStats
-- Calculates total count and average score for a specific Genre.
-- Inputs: Genre Name
-- Outputs: Count, Average Score
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS GetGenreStats //
CREATE PROCEDURE GetGenreStats(
    IN p_genre_name VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci, 
    OUT p_total_count INT, 
    OUT p_avg_score DECIMAL(4,2)
)
BEGIN
    SELECT COUNT(*), AVG(e.score)
    INTO p_total_count, p_avg_score
    FROM Entry e
    JOIN EntryGenre eg ON e.entry_id = eg.entry_id
    JOIN Genre g ON eg.genre_id = g.genre_id
    WHERE g.name = p_genre_name;
END //

-- -----------------------------------------------------------------------------
-- 2. GetStudioSuccessRate
-- Gets the number of hits (Score > 7.5) and total produced by a Studio.
-- Inputs: Studio Name
-- Outputs: Total Anime, Hit Count, Success Rate (%)
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS GetStudioSuccessRate //
CREATE PROCEDURE GetStudioSuccessRate(
    IN p_studio_name VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_total_anime INT,
    OUT p_hit_count INT,
    OUT p_success_rate DECIMAL(5,2)
)
BEGIN
    SELECT 
        COUNT(*), 
        SUM(CASE WHEN e.score >= 7.5 THEN 1 ELSE 0 END)
    INTO p_total_anime, p_hit_count
    FROM Entry e
    JOIN EntryStudio es ON e.entry_id = es.entry_id
    JOIN Studio s ON es.studio_id = s.studio_id
    WHERE s.name = p_studio_name;

    IF p_total_anime > 0 THEN
        SET p_success_rate = (p_hit_count / p_total_anime) * 100;
    ELSE
        SET p_success_rate = 0;
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 3. GetTopRankedByYear
-- returns the highest scored anime title for a given year.
-- Inputs: Year
-- Outputs: Title, Score
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS GetTopRankedByYear //
CREATE PROCEDURE GetTopRankedByYear(
    IN p_year SMALLINT,
    OUT p_top_title VARCHAR(255),
    OUT p_top_score DECIMAL(4,2)
)
BEGIN
    SELECT e.title_name, e.score
    INTO p_top_title, p_top_score
    FROM Entry e
    JOIN AnimeDetails ad ON e.entry_id = ad.entry_id
    WHERE ad.premier_date_year = p_year
    ORDER BY e.score DESC
    LIMIT 1;
END //

-- -----------------------------------------------------------------------------
-- 4. CountMangaByStatus
-- Counts how many manga exist for a certain status.
-- Inputs: Status Name (e.g., 'Publishing')
-- Outputs: Count
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS CountMangaByStatus //
CREATE PROCEDURE CountMangaByStatus(
    IN p_status_name VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_count INT
)
BEGIN
    SELECT COUNT(*)
    INTO p_count
    FROM Entry e
    JOIN MangaDetails md ON e.entry_id = md.entry_id
    JOIN StatusType st ON md.status_id = st.status_id
    WHERE st.status_name = p_status_name;
END //

-- -----------------------------------------------------------------------------
-- 5. GetThemePopularity
-- Calculates avg popularity rank for a Theme (Lower is better).
-- Inputs: Theme Name
-- Outputs: Avg Popularity Rank
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS GetThemePopularity //
CREATE PROCEDURE GetThemePopularity(
    IN p_theme_name VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_avg_popularity DECIMAL(10,2)
)
BEGIN
    SELECT AVG(e.popularity)
    INTO p_avg_popularity
    FROM Entry e
    JOIN EntryTheme et ON e.entry_id = et.entry_id
    JOIN Theme t ON et.theme_id = t.theme_id
    WHERE t.name = p_theme_name;
END //


-- -----------------------------------------------------------------------------
-- 6. UpdateEntryScore
-- Updates the score of an entry and returns the updated value.
-- Inputs: Entry ID, New Score (INOUT)
-- Outputs: Confirmed New Score
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS UpdateEntryScore //
CREATE PROCEDURE UpdateEntryScore(
    IN     p_entry_id INT UNSIGNED,
    INOUT  p_score    DECIMAL(4,2)
)
BEGIN
    -- update score
    UPDATE Entry
    SET score = p_score
    WHERE entry_id = p_entry_id;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Entry not found';
    END IF;

    -- return actual stored value
    SELECT score INTO p_score
    FROM Entry
    WHERE entry_id = p_entry_id;
END //


-- -----------------------------------------------------------------------------
-- 7. GetOrCreateGenre
-- Finds a genre by name or creates it if missing, then returns its ID.
-- Inputs: Genre Name
-- Outputs: Genre ID
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS GetOrCreateGenre //
CREATE PROCEDURE GetOrCreateGenre(
    IN     p_genre_name VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    INOUT  p_genre_id   INT UNSIGNED
)
BEGIN
    DECLARE v_id INT UNSIGNED;

    SELECT genre_id INTO v_id
    FROM Genre
    WHERE name = p_genre_name
    LIMIT 1;

    IF v_id IS NULL THEN
        INSERT INTO Genre(name) VALUES(p_genre_name);
        SET v_id = LAST_INSERT_ID();
    END IF;

    SET p_genre_id = v_id;
END //


-- -----------------------------------------------------------------------------
-- 8. AddEntryGenre
-- Links an Entry to a Genre if the link doesn't already exist.
-- Inputs: Entry ID, Genre ID
-- Outputs: Added Flag (1 = Added, 0 = Exists)
-- Usage: SET @added = 0; CALL AddEntryGenre(1, 5, @added); SELECT @added;
-- -----------------------------------------------------------------------------
delimiter //
DROP PROCEDURE IF EXISTS AddEntryGenre //
CREATE PROCEDURE AddEntryGenre(
    IN     p_entry_id INT UNSIGNED,
    IN     p_genre_id INT UNSIGNED,
    INOUT  p_added    TINYINT
)
BEGIN
    SET p_added = 0;

    IF NOT EXISTS (
        SELECT 1 FROM EntryGenre
        WHERE entry_id = p_entry_id AND genre_id = p_genre_id
    ) THEN
        INSERT INTO EntryGenre(entry_id, genre_id)
        VALUES(p_entry_id, p_genre_id);
        SET p_added = 1;
    END IF;
END //


DELIMITER ;
