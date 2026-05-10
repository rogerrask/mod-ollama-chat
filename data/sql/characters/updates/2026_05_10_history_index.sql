-- Migration: Add composite index on mod_ollama_chat_history (bot_guid, player_guid)
--
-- This index speeds up the per-pair DELETE that trims history to the configured limit,
-- and any range queries filtering by bot and player together.
--
-- Compatible with MySQL 5.7 and MariaDB 10.1+ (no IF NOT EXISTS on ALTER TABLE INDEX).
-- Uses a conditional PREPARE/EXECUTE pattern to skip creation if the index already exists.

SET @dbname    = DATABASE();
SET @tablename = 'mod_ollama_chat_history';
SET @indexname = 'idx_bot_player';
SET @columnlist = 'bot_guid, player_guid';

SET @sqlstmt = (
    SELECT IF(
        EXISTS (
            SELECT 1
            FROM information_schema.statistics
            WHERE table_schema = @dbname
              AND table_name    = @tablename
              AND index_name    = @indexname
        ),
        'SELECT ''Index idx_bot_player already exists, skipping.''',
        CONCAT('ALTER TABLE `', @tablename, '` ADD INDEX `', @indexname, '` (', @columnlist, ')')
    )
);

PREPARE st FROM @sqlstmt;
EXECUTE st;
DEALLOCATE PREPARE st;
