-- =========================================================
-- Views
-- =========================================================

USE myanimelist_db_v2;

-- -----------------------------------------------------------------------------
-- 1. View_TopAnimeSummary
-- A simple summary of highly rated anime (Score > 8.0).
-- Joins: Entry, AnimeDetails, StatusType
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS View_TopAnimeSummary;
CREATE VIEW View_TopAnimeSummary AS
SELECT 
    e.ranked,
    e.title_name, 
    e.score, 
    st.status_name,
    ad.episodes,
    ad.duration_minutes,
    ad.premier_date_year AS year
FROM Entry e
JOIN AnimeDetails ad ON e.entry_id = ad.entry_id
LEFT JOIN StatusType st ON ad.status_id = st.status_id
WHERE e.score >= 8.0;

-- -----------------------------------------------------------------------------
-- 2. View_StudioPerformance
-- Aggregated statistics for every studio.
-- Joins: Entry, EntryStudio, Studio
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS View_StudioPerformance;
CREATE VIEW View_StudioPerformance AS
SELECT 
    s.name AS StudioName,
    COUNT(e.entry_id) AS TotalWorks,
    ROUND(AVG(e.score), 2) AS AvgScore,
    ROUND(AVG(e.popularity), 0) AS AvgPopularity
FROM Studio s
JOIN EntryStudio es ON s.studio_id = es.studio_id
JOIN Entry e ON es.entry_id = e.entry_id
GROUP BY s.name;

-- -----------------------------------------------------------------------------
-- 3. View_GenreDemographics
-- Shows which genres are most common within specific demographics (Shounen, Seinen, etc).
-- Joins: Entry, EntryGenre, Genre, EntryDemographic, Demographic
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS View_GenreDemographics;
CREATE VIEW View_GenreDemographics AS
SELECT 
    d.name AS Demographic,
    g.name AS Genre,
    COUNT(*) AS EntryCount
FROM Entry e
JOIN EntryDemographic ed ON e.entry_id = ed.entry_id
JOIN Demographic d ON ed.demographic_id = d.demographic_id
JOIN EntryGenre eg ON e.entry_id = eg.entry_id
JOIN Genre g ON eg.genre_id = g.genre_id
GROUP BY d.name, g.name;

-- -----------------------------------------------------------------------------
-- 4. View_CurrentSeasonAnime
-- Shows currently airing anime from the latest year in the dataset.
-- Joins: Entry, AnimeDetails, StatusType
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS View_CurrentSeasonAnime;
CREATE VIEW View_CurrentSeasonAnime AS
SELECT 
    e.title_name,
    ad.premier_date_season,
    ad.premier_date_year,
    ad.broadcast_date_day AS BroadcastDay,
    st.status_name
FROM Entry e
JOIN AnimeDetails ad ON e.entry_id = ad.entry_id
JOIN StatusType st ON ad.status_id = st.status_id
WHERE st.status_name = 'Currently Airing'
  AND ad.premier_date_year = (SELECT MAX(ad.premier_date_year) FROM AnimeDetails)
ORDER BY ad.premier_date_year desc;

-- -----------------------------------------------------------------------------
-- 5. View_MangaLongRunners
-- Lists manga with substantial volume counts (> 20 volumes).
-- Joins: Entry, MangaDetails, Author
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS View_MangaLongRunners;
CREATE VIEW View_MangaLongRunners AS
SELECT 
    e.title_name,
    md.chapters,
    e.score,
    GROUP_CONCAT(CONCAT_WS(' ', a.first_name, a.last_name) SEPARATOR ', ') AS Authors
FROM Entry e
JOIN MangaDetails md ON e.entry_id = md.entry_id
LEFT JOIN EntryAuthor ea ON e.entry_id = ea.entry_id
LEFT JOIN Author a ON ea.author_id = a.author_id
WHERE md.volumes > 20
GROUP BY e.entry_id, e.title_name, md.volumes, md.chapters, e.score;
