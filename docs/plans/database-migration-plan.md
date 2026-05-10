# Database Migration Plan

> **Scope:** Ordering, compatibility, and exact SQL for all database changes across the refactor phases.

---

## Current Schema State

Four tables exist, all in the `acore_characters` database:

| Table | Created By | Purpose |
|-------|-----------|---------|
| `mod_ollama_chat_personality` | `2025_03_30_personalities.sql` | Bot personality assignments |
| `mod_ollama_chat_personality_templates` | `2025_05_31_personality_template.sql` | Personality definitions |
| `mod_ollama_chat_history` | `2025_06_14_chat_history.sql` | Conversation history |
| `mod_ollama_chat_sentiment` | `2025_07_24_sentiment_tracking.sql` | Sentiment scores |

Full DDL: see [current-state/database-schema.md](../current-state/database-schema.md).

---

## Migration File Naming Convention

All migration files go in `data/sql/characters/updates/` and follow this naming pattern:

```
YYYY_MM_DD_description.sql
```

Migrations must be idempotent where possible (use `IF NOT EXISTS`, `IF EXISTS`, or guarded `ALTER TABLE`).

---

## Phase 2 Migrations

### Migration 1: Add Index on `mod_ollama_chat_history`

**File:** `data/sql/characters/updates/2025_XX_XX_history_index.sql`

The `ADD INDEX IF NOT EXISTS` syntax is not available in all MySQL and MariaDB versions:
- MySQL < 8.0: not supported
- MariaDB < 10.1.4: not supported

Use a conditional pattern instead:

```sql
-- Compatible with MySQL 5.7, MariaDB 10.1+
SET @dbname = DATABASE();
SET @tablename = 'mod_ollama_chat_history';
SET @indexname = 'idx_bot_player';
SET @columnlist = 'bot_guid, player_guid';
SET @sqlstmt = (
    SELECT IF(
        EXISTS (
            SELECT 1 FROM information_schema.statistics
            WHERE table_schema = @dbname
              AND table_name = @tablename
              AND index_name = @indexname
        ),
        'SELECT ''Index already exists.''',
        CONCAT('ALTER TABLE ', @tablename, ' ADD INDEX ', @indexname, ' (', @columnlist, ')')
    )
);
PREPARE st FROM @sqlstmt;
EXECUTE st;
DEALLOCATE PREPARE st;
```

**Verification:** Run `SHOW INDEX FROM mod_ollama_chat_history` — confirm `idx_bot_player` is present.

---

### Migration 2: Fix History Cleanup Query Compatibility

The `SaveBotConversationHistoryToDB()` function uses a CTE to delete excess rows. CTEs require MySQL 8.0+ or MariaDB 10.2.1+.

**Replacement pattern** (MySQL 5.7 / MariaDB 10.1 compatible):

```sql
-- Delete rows beyond the N most recent per bot_guid + player_guid
DELETE FROM mod_ollama_chat_history
WHERE id NOT IN (
    SELECT id FROM (
        SELECT id
        FROM mod_ollama_chat_history
        WHERE bot_guid = ? AND player_guid = ?
        ORDER BY timestamp DESC
        LIMIT ?
    ) AS recent
)
AND bot_guid = ?
AND player_guid = ?;
```

This is a code change in `src/mod-ollama-chat_handler.cpp`, not a migration file. It is listed here for traceability.

**Note:** The `DELETE ... WHERE id NOT IN (SELECT ... FROM same_table)` pattern is not allowed in MySQL/MariaDB without the subquery alias (`AS recent`). The alias is required.

---

## Phase 5 Migrations

### Review of Base SQL Files

All base SQL files must be reviewed for:
- Use of `IF NOT EXISTS` on `CREATE TABLE` — **required** to allow clean re-run
- Correct table names matching code
- No hardcoded database names in table DDL (table names only, not qualified names)

Current base files:
- `2025_03_30_personalities.sql` — verify `CREATE TABLE IF NOT EXISTS`
- `2025_05_30_personalities.sql` — purpose unclear (duplicate month?) — review
- `2025_05_31_personality_template.sql` — verify `CREATE TABLE IF NOT EXISTS`
- `2025_06_14_chat_history.sql` — verify `CREATE TABLE IF NOT EXISTS`
- `2025_07_24_sentiment_tracking.sql` — verify `CREATE TABLE IF NOT EXISTS`
- `2025_11_01_personality_manual_only.sql` — verify schema change is additive

### Add `manual_only` Column Migration

If `2025_11_01_personality_manual_only.sql` adds the `manual_only` column to `mod_ollama_chat_personality_templates`, it must handle the case where the column already exists (upgrade from a fresh install that ran the later base file).

Recommended pattern:
```sql
ALTER TABLE mod_ollama_chat_personality_templates
    ADD COLUMN IF NOT EXISTS manual_only TINYINT(1) NOT NULL DEFAULT 0;
```

`ADD COLUMN IF NOT EXISTS` is supported in MariaDB 10.0.2+. For MySQL < 8.0, use the conditional prepare/execute pattern shown in Migration 1.

---

## DB Name Hardcoding Issue (KI-11)

The `LoadPersonalityTemplatesFromDB()` function contains a query against `information_schema.tables` that hardcodes `'acore_characters'` as the database name. This is incorrect on servers using a different database name.

**Fix (Phase 1 task 1.4):** Replace with a dynamic call:

```cpp
// Instead of:
// "WHERE TABLE_SCHEMA = 'acore_characters' AND TABLE_NAME = 'mod_ollama_chat_personality_templates'"

// Use:
std::string dbName = CharacterDatabase.GetDatabaseName(); // or equivalent AC API
std::string query = "WHERE TABLE_SCHEMA = '" + dbName + "' AND TABLE_NAME = 'mod_ollama_chat_personality_templates'";
```

If the AC API does not expose `GetDatabaseName()`, use a configurable key `OllamaChat.CharactersDBName` as a fallback, defaulting to `acore_characters`.

---

## Migration Execution Order

For a fresh install, run base files in this order:
1. `2025_03_30_personalities.sql`
2. `2025_05_30_personalities.sql` (if distinct)
3. `2025_05_31_personality_template.sql`
4. `2025_06_14_chat_history.sql`
5. `2025_07_24_sentiment_tracking.sql`
6. `2025_11_01_personality_manual_only.sql`

For an existing install, run update files in date order from the `updates/` directory.

**There is no migration runner.** Migrations must be applied manually via MySQL client or via AzerothCore's DB updater if the module is integrated with it.

---

## Compatibility Matrix

| Feature | MySQL 5.7 | MySQL 8.0 | MariaDB 10.1 | MariaDB 10.6 |
|---------|----------|----------|-------------|-------------|
| `CREATE TABLE IF NOT EXISTS` | ✅ | ✅ | ✅ | ✅ |
| `ADD COLUMN IF NOT EXISTS` | ✗ | ✅ | ✅ (10.0.2+) | ✅ |
| `ADD INDEX IF NOT EXISTS` | ✗ | ✅ | ✅ (10.1.4+) | ✅ |
| CTE (WITH clause) in DML | ✗ | ✅ | ✅ (10.2.1+) | ✅ |
| information_schema.statistics | ✅ | ✅ | ✅ | ✅ |

**AzerothCore supports MySQL 5.7 and MariaDB 10.x.** All migrations must work on MySQL 5.7.
