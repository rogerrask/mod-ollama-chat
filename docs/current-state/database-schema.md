# Database Schema

> **Scope:** All DDL from `data/sql/characters/base/`. All claims are **[source-backed]** unless marked. Apply SQL files in date order on a fresh install.

---

## Tables

### 1. `mod_ollama_chat_personality`

**Purpose:** Stores the assigned personality key for each bot GUID.

**Source:** `data/sql/characters/base/2025_05_30_personalities.sql` (supersedes `2025_03_30_personalities.sql`)

```sql
CREATE TABLE IF NOT EXISTS `mod_ollama_chat_personality` (
  `guid`        BIGINT       NOT NULL,
  `personality` VARCHAR(64)  NOT NULL,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Read by:** `LoadBotPersonalityList()` in `config.cpp` — loads all rows into `g_BotPersonalityList` map on startup. **[source-backed: config.cpp]**

**Written by:**
- `GetBotPersonality()` in `personality.cpp` — INSERT on first personality assignment for a new bot
- `SetBotPersonality()` in `personality.cpp` — REPLACE to change a bot's personality

**Note:** The first SQL file (`2025_03_30`) used `INT guid` and is superseded. Do not apply both. Apply only `2025_05_30` for the correct schema. **[source-backed]**

---

### 2. `mod_ollama_chat_personality_templates`

**Purpose:** Stores named personality definitions — the text injected into prompts when a bot has a given personality.

**Source:** `data/sql/characters/base/2025_05_31_personality_template.sql` + `data/sql/characters/base/2025_11_01_personality_manual_only.sql`

```sql
CREATE TABLE IF NOT EXISTS `mod_ollama_chat_personality_templates` (
  `key`         VARCHAR(64)  NOT NULL PRIMARY KEY,
  `prompt`      TEXT         NOT NULL,
  `manual_only` TINYINT(1)   NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

The `manual_only` column was added by the `2025_11_01` migration. Apply that migration after the base table is created. **[source-backed]**

**Seed data** (from `2025_05_31_personality_template.sql`):

| key | prompt (excerpt) | manual_only |
|-----|-----------------|-------------|
| GAMER | Focus on game mechanics, min-maxing, and efficiency. | 0 |
| ROLEPLAYER | Respond in-character, weaving lore into your response. | 0 |
| LOOTGOBLIN | Talk about rare loot, gold strategies, and treasure hunting. | 0 |
| PVP_HARDCORE | Discuss PvP strategies, dueling tactics, and battleground dominance. | 0 |
| *(more rows in file)* | | |

**Read by:** `LoadOllamaChatConfig()` — reads into `g_PersonalityPrompts` map and `g_PersonalityKeys` / `g_PersonalityKeysRandomOnly` vectors. `manual_only = 1` entries go into `g_PersonalityKeys` only (excluded from random assignment). **[source-backed: config.cpp]**

**Written by:** Not written at runtime. Personality templates are populated via SQL only.

---

### 3. `mod_ollama_chat_history`

**Purpose:** Persists conversation history (player message + bot reply pairs) between server restarts.

**Source:** `data/sql/characters/base/2025_06_14_chat_history.sql`

```sql
CREATE TABLE IF NOT EXISTS mod_ollama_chat_history (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  bot_guid       BIGINT UNSIGNED NOT NULL,
  player_guid    BIGINT UNSIGNED NOT NULL,
  timestamp      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  player_message TEXT            NOT NULL,
  bot_reply      TEXT            NOT NULL,
  UNIQUE KEY unique_history (bot_guid, player_guid, player_message(255), bot_reply(255))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**Written by:** `SaveBotConversationHistoryToDB()` in `handler.cpp`:
- `INSERT IGNORE` using `EscapeString()` + `SafeFormat()` pattern ← **KI-05 (SQL injection surface)**
- CTE-based DELETE cleanup to keep only the N most recent rows per bot/player pair ← **KI-04 (MySQL 8.0+ only)**

**Read by:** `LoadBotConversationHistoryFromDB()` — reads recent history into `g_BotConversationHistory` on startup and after reload. **[source-backed: command.cpp reload handler]**

**Missing index:** No index on `(bot_guid, player_guid)` for efficient per-pair queries. **[source-backed — KI-12]**

---

### 4. `mod_ollama_chat_bot_player_sentiments`

**Purpose:** Persists the sentiment score (0.0 hostile → 0.5 neutral → 1.0 friendly) between each bot and player pair.

**Source:** `data/sql/characters/base/2025_07_24_sentiment_tracking.sql`

```sql
CREATE TABLE IF NOT EXISTS mod_ollama_chat_bot_player_sentiments (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  bot_guid        BIGINT UNSIGNED NOT NULL,
  player_guid     BIGINT UNSIGNED NOT NULL,
  sentiment_value FLOAT           NOT NULL DEFAULT 0.5,
  last_updated    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_sentiment (bot_guid, player_guid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**Written by:** `SaveBotPlayerSentimentsToDB()` in `sentiment.cpp` — periodic flush from `g_BotPlayerSentiments` in-memory map. **[source-backed]**

**Read by:** `InitializeSentimentTracking()` — loads all rows into `g_BotPlayerSentiments` map on startup and reload. **[source-backed]**

**Missing index:** The UNIQUE KEY on `(bot_guid, player_guid)` doubles as a lookup index. An explicit index on these columns would improve read performance but may be redundant given the UNIQUE KEY. **[inferred]**

---

## Migration Order

Apply these files in this exact order on a fresh install:

```
1. data/sql/characters/base/2025_05_30_personalities.sql
   (skip 2025_03_30 — it is superseded)

2. data/sql/characters/base/2025_05_31_personality_template.sql

3. data/sql/characters/base/2025_06_14_chat_history.sql

4. data/sql/characters/base/2025_07_24_sentiment_tracking.sql

5. data/sql/characters/base/2025_11_01_personality_manual_only.sql
```

For existing installs, apply only the migrations that have not yet been applied. **[inferred from file date convention]**

The `data/sql/characters/updates/` directory exists but is empty. **[source-backed]**

---

## Known Issues

| Issue | ID | Description |
|-------|----|-------------|
| CTE cleanup incompatibility | KI-04 | `WITH ... DELETE` syntax requires MySQL 8.0+ / MariaDB 10.2.1+ |
| SQL injection surface | KI-05 | INSERT uses EscapeString + string interpolation, not parameterized queries |
| Missing index on history | KI-12 | `(bot_guid, player_guid)` lookup unindexed in `mod_ollama_chat_history` |

See [known-issues.md](known-issues.md) for full details and fix phases.

---

## Notes

- No foreign key constraints exist between any module tables. **[source-backed: SQL files]**
- All tables use `ENGINE=InnoDB` and `utf8mb4` charset. **[source-backed]**
- `mod_ollama_chat_personality_templates` data is managed purely via SQL; the module only reads it.
- All in-memory data (`g_BotConversationHistory`, `g_BotPersonalityList`, `g_BotPlayerSentiments`) is loaded from DB on startup and periodically flushed back. A server crash between flushes will lose data accumulated since the last save. **[inferred]**
