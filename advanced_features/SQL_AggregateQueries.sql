-- =========================================================
-- Aggregate Queries
-- =========================================================

USE myanimelist_db_v2;

-- -----------------------------------------------------------------------------
-- I. Average user score for entries grouped by target demographic
-- -----------------------------------------------------------------------------
SELECT 
    d.name AS Demographic,
    ROUND(AVG(e.score), 2) AS AverageScore
FROM Entry e
JOIN EntryDemographic ed ON e.entry_id = ed.entry_id
JOIN Demographic d ON ed.demographic_id = d.demographic_id
GROUP BY d.name
ORDER BY AverageScore DESC;

-- -----------------------------------------------------------------------------
-- II. Total sum of members tracking entries for each distinct media type
-- -----------------------------------------------------------------------------
SELECT 
    m.name AS Medium,
    it.type_name AS MediaType,
    SUM(e.members) AS TotalMembers
FROM Entry e
JOIN ItemType it ON e.item_type_id = it.item_type_id
JOIN Medium m ON it.medium_id = m.medium_id
GROUP BY m.name, it.type_name
ORDER BY TotalMembers DESC;

-- -----------------------------------------------------------------------------
-- III. Number of anime titles listed under each age rating category
-- -----------------------------------------------------------------------------
SELECT 
    ar.code AS AgeRating,
    COUNT(*) AS AnimeCount
FROM Entry e
JOIN AnimeDetails ad ON e.entry_id = ad.entry_id
JOIN AgeRating ar ON ad.age_rating_id = ar.age_rating_id
GROUP BY ar.code
ORDER BY AnimeCount DESC;

-- -----------------------------------------------------------------------------
-- IV. Maximum episode count produced by each animation studio
-- -----------------------------------------------------------------------------
SELECT 
    s.name AS Studio,
    MAX(ad.episodes) AS MaxEpisodes
FROM Entry e
JOIN AnimeDetails ad ON e.entry_id = ad.entry_id
JOIN EntryStudio es ON e.entry_id = es.entry_id
JOIN Studio s ON es.studio_id = s.studio_id
GROUP BY s.name
ORDER BY MaxEpisodes DESC
LIMIT 50; -- Limit to top 50 to avoid cluttering output

-- -----------------------------------------------------------------------------
-- V. Average number of manga volumes based on their publishing status
-- -----------------------------------------------------------------------------
SELECT 
    st.status_name AS PublishingStatus,
    ROUND(AVG(md.volumes), 2) AS AvgVolumes
FROM Entry e
JOIN MangaDetails md ON e.entry_id = md.entry_id
JOIN StatusType st ON md.status_id = st.status_id
GROUP BY st.status_name
ORDER BY AvgVolumes DESC;

-- -----------------------------------------------------------------------------
-- VI. Total number of user favorites for all entries within each genre
-- -----------------------------------------------------------------------------
SELECT 
    g.name AS Genre,
    SUM(e.favorited) AS TotalFavorites
FROM Entry e
JOIN EntryGenre eg ON e.entry_id = eg.entry_id
JOIN Genre g ON eg.genre_id = g.genre_id
GROUP BY g.name
ORDER BY TotalFavorites DESC;

-- -----------------------------------------------------------------------------
-- VII. Lowest anime score recorded for each adaptation source material
-- -----------------------------------------------------------------------------
SELECT 
    s.source_name AS SourceMaterial,
    MIN(e.score) AS LowestScore
FROM Entry e
JOIN AnimeDetails ad ON e.entry_id = ad.entry_id
JOIN Source s ON ad.source_id = s.source_id
GROUP BY s.source_name
ORDER BY LowestScore ASC;

-- -----------------------------------------------------------------------------
-- VIII. Total count of chapters released in each serialization magazine
-- -----------------------------------------------------------------------------
SELECT 
    s.name AS Magazine,
    SUM(md.chapters) AS TotalChaptersReleased
FROM Entry e
JOIN MangaDetails md ON e.entry_id = md.entry_id
JOIN EntrySerialization es ON e.entry_id = es.entry_id
JOIN Serialization s ON es.serialization_id = s.serialization_id
GROUP BY s.name
ORDER BY TotalChaptersReleased DESC
LIMIT 50;

-- -----------------------------------------------------------------------------
-- IX. Count distinct works associated with each specific author
-- -----------------------------------------------------------------------------
SELECT 
    CONCAT_WS(', ', a.last_name, a.first_name) AS Author,
    COUNT(e.entry_id) AS WorksCount
FROM Entry e
JOIN EntryAuthor ea ON e.entry_id = ea.entry_id
JOIN Author a ON ea.author_id = a.author_id
GROUP BY Author
ORDER BY WorksCount DESC
LIMIT 50;

-- -----------------------------------------------------------------------------
-- X. Average popularity ranking for anime titles from each producer
-- -----------------------------------------------------------------------------
SELECT 
    p.name AS Producer,
    ROUND(AVG(e.popularity), 0) AS AvgPopularityRank
FROM Entry e
JOIN EntryProducer ep ON e.entry_id = ep.entry_id
JOIN Producer p ON ep.producer_id = p.producer_id
GROUP BY p.name
ORDER BY AvgPopularityRank ASC -- Lower rank is better (more popular)
LIMIT 50;
