# Known Issues

> **Scope:** Issues identified from static code review (May 2026). None have been verified by in-game testing unless explicitly marked. All are **[source-backed]** unless marked **[inferred]**.
>
> Format: **ID** | **Severity** | **Description** | **Location** | **Fix Phase**

---

## High Severity

### KI-01 — Detached Threads With No Lifecycle Management
**Severity:** High  
**Location:** `src/mod-ollama-chat_querymanager.cpp`, `QueryManager::processQuery()`  
**Fix Phase:** Phase 4  

`std::thread(&QueryManager::processQuery, ...).detach()` is used for every LLM query. Detached threads have no handle and cannot be joined or cancelled. If the server shuts down while queries are in-flight, these threads continue executing against a partially destroyed server state, which may cause crashes or undefined behavior.

Additionally, if `g_MaxConcurrentQueries` is 0 (the default — unlimited), a burst of chat messages can spawn an unbounded number of threads simultaneously. **[source-backed: querymanager.cpp]**

---

### KI-02 — Mutex Held During All DB Writes in History Save
**Severity:** High  
**Location:** `src/mod-ollama-chat_handler.cpp`, `SaveBotConversationHistoryToDB()`  
**Fix Phase:** Phase 4  

`g_ConversationHistoryMutex` is held for the entire duration of `SaveBotConversationHistoryToDB()`, which includes nested loops and multiple `CharacterDatabase.Execute()` calls. Any thread calling `AppendBotConversation()` (which also needs the mutex) will block for the full duration of the DB save, increasing response latency. **[source-backed: handler.cpp]**

---

### KI-03 — Synchronous Sentiment LLM Call on Calling Thread
**Severity:** High  
**Location:** `src/mod-ollama-chat_sentiment.cpp`, `AnalyzeMessageSentiment()`  
**Fix Phase:** Phase 4  

When `g_EnableSentimentTracking` is true, `AnalyzeMessageSentiment()` calls `QueryOllamaAPI()` directly on the same thread that is processing the player's chat message. This is a synchronous, blocking HTTP call. If the Ollama endpoint is slow, this blocks the calling thread for up to 120 seconds (the HTTP timeout). **[source-backed: sentiment.cpp]**

Sentiment is disabled by default (`OllamaChat.EnableSentimentTracking = 0`), which mitigates this risk unless explicitly enabled. **[source-backed: conf.dist]**

---

### KI-04 — CTE DELETE Incompatible With MySQL 5.7 / MariaDB < 10.2.1
**Severity:** High  
**Location:** `src/mod-ollama-chat_handler.cpp`, `SaveBotConversationHistoryToDB()`  
**Fix Phase:** Phase 2  

The cleanup query uses a CTE (`WITH ranked_history AS (...) DELETE FROM ...`). This syntax requires MySQL 8.0+ or MariaDB 10.2.1+. AzerothCore is commonly deployed on MariaDB 10.x or MySQL 5.7, where this query will fail silently (or with an error log). The `INSERT IGNORE` inserts still succeed; only the old-row cleanup fails. **[source-backed: handler.cpp]**

---

## Medium Severity

### KI-05 — SQL Injection Surface in History Save
**Severity:** Medium  
**Location:** `src/mod-ollama-chat_handler.cpp`, `SaveBotConversationHistoryToDB()`  
**Fix Phase:** Phase 2  

Player messages and bot replies are passed through `CharacterDatabase.EscapeString()` then interpolated into the SQL string via `SafeFormat()`. While `EscapeString` is intended to prevent injection, the pattern of string interpolation into SQL is inherently fragile and is not the recommended approach for AzerothCore's DB layer. The recommended pattern is passing values as separate arguments to `Execute()`, which handles escaping internally. **[source-backed: handler.cpp]**

---

### KI-06 — Static HTTP Client Not Reset on Config Reload
**Severity:** Medium  
**Location:** `src/mod-ollama-chat_api.cpp`, `QueryOllamaAPI()`  
**Fix Phase:** Phase 4  

`OllamaHttpClient httpClient` is declared `static` inside `QueryOllamaAPI()`. It is initialized on the first call and reused for all subsequent calls. If the operator changes `OllamaChat.Url` and runs `.ollama reload`, the new URL is stored in `g_OllamaUrl` but the existing `httpClient` instance still parses the URL on each `Post()` call from `g_OllamaUrl` — so the URL change **does** take effect. However, timeout changes and any client-level configuration do not take effect until server restart. **[source-backed: api.cpp, httpclient.cpp]**

Note: The URL is re-read from `g_OllamaUrl` on every `Post()` call, so URL changes via reload work. Only client-level state (like timeout) is stale. This is a partial issue. **[inferred — nuance from httpclient.cpp Post() implementation]**

---

### KI-07 — QueryManager Reads Config Before Config Is Loaded
**Severity:** Medium  
**Location:** `src/mod-ollama-chat_querymanager.cpp`, `QueryManager::QueryManager()`  
**Fix Phase:** Phase 1  

The `QueryManager` global `g_queryManager` is constructed at static initialization time. Its constructor reads `g_MaxConcurrentQueries`:

```cpp
QueryManager::QueryManager()
    : maxConcurrentQueries(g_MaxConcurrentQueries), currentQueries(0)
{}
```

At this point, `LoadOllamaChatConfig()` has not yet been called, so `g_MaxConcurrentQueries` is its default-initialized value (0). The configured value is never applied unless explicitly reset later. **[source-backed: querymanager.cpp]**

In practice, since 0 means "no limit", the behavior may appear correct — but the configured limit is never enforced. **[inferred]**

---

### KI-08 — SplitString Defined in Two Places
**Severity:** Medium  
**Location:** `src/mod-ollama-chat_config.cpp` (static function), `src/mod-ollama-chat-utilities.h` (inline function)  
**Fix Phase:** Phase 1  

Two identical `SplitString` functions exist. The one in `config.cpp` is `static` (translation-unit local). The one in `utilities.h` is `inline`. Any future changes must be made in both places. **[source-backed]**

---

## Low Severity

### KI-09 — Raw Pointer for RAG System
**Severity:** Low  
**Location:** `src/mod-ollama-chat_config.cpp`, `g_RAGSystem`  
**Fix Phase:** Phase 1  

`OllamaRAGSystem* g_RAGSystem = nullptr` is a raw pointer. If `LoadOllamaChatConfig()` is called multiple times (e.g., via `.ollama reload`) and `g_EnableRAG` is toggled, the pointer could be replaced without deleting the previous object, causing a memory leak. **[source-backed: config.cpp — exact reload behavior inferred]**

---

### KI-10 — Dead Code in GetBotPersonality()
**Severity:** Low  
**Location:** `src/mod-ollama-chat_personality.cpp`, `GetBotPersonality()`  
**Fix Phase:** Phase 1  

After an early `return` branch for bots already in `g_BotPersonalityList`, a second `g_BotPersonalityList.find(botGuid)` check is performed. This second check can never succeed because the first check already returned if found. The second block is unreachable dead code. **[source-backed: personality.cpp]**

---

### KI-11 — Hardcoded Database Name in information_schema Query
**Severity:** Low  
**Location:** `src/mod-ollama-chat_personality.cpp`, `GetBotPersonality()` and `src/mod-ollama-chat_config.cpp`, `LoadBotPersonalityList()`  
**Fix Phase:** Phase 1  

```sql
SELECT * FROM information_schema.tables
WHERE table_schema = 'acore_characters'
AND table_name = 'mod_ollama_chat_personality' LIMIT 1
```

This hardcodes the database name `acore_characters`. If the operator has renamed their character database, this check silently fails and the module assumes the table does not exist, logging an error and skipping personality loading. **[source-backed]**

---

### KI-12 — Missing Performance Indexes on History Table
**Severity:** Low  
**Location:** `data/sql/characters/base/2025_06_14_chat_history.sql`  
**Fix Phase:** Phase 5  

`mod_ollama_chat_history` has a UNIQUE KEY on `(bot_guid, player_guid, player_message(255), bot_reply(255))` but no plain index on `(bot_guid, player_guid, timestamp)`. Queries that load recent history per bot/player pair must scan the full table or rely on the unique key prefix. For servers with many bots and active chat history, this may be slow. **[source-backed]**

---

### KI-13 — ExtractTextBetweenDoubleQuotes May Discard Valid Response Content
**Severity:** Low  
**Location:** `src/mod-ollama-chat_api.cpp`, `ExtractTextBetweenDoubleQuotes()`  
**Fix Phase:** Phase 3  

If the LLM response naturally contains a quoted phrase (e.g., `I said "come on then" and left`), this function returns only `come on then` and discards `I said ` and ` and left`. The intent is to strip responses that are wrapped in outer quotes (a common LLM output habit), but the implementation does not distinguish outer quotes from mid-sentence quotes. Actual impact frequency is **[unknown]** without in-game testing.

---

### KI-14 — Commented-Out Debug Logging in api.cpp
**Severity:** Low  
**Location:** `src/mod-ollama-chat_api.cpp`  
**Fix Phase:** Phase 1  

Several `LOG_INFO` calls are commented out in `api.cpp`. These are dead code that adds visual noise. **[source-backed]**

---

## Unknown Severity

### KI-15 — Personality DB Persistence Reliability
**Severity:** Unknown  
**Location:** `src/mod-ollama-chat_personality.cpp`, `GetBotPersonality()`  
**Fix Phase:** Phase 1 (partial)  

The first-time personality assignment flow does an `information_schema` check (see KI-11) then `INSERT INTO mod_ollama_chat_personality`. Whether this INSERT succeeds reliably across different AzerothCore builds, DB configurations, and character DB names has not been verified in-game. **[source-backed code path — in-game status unknown]**

---

### KI-16 — ThinkMode hidethinking Behavior Across Models
**Severity:** Unknown  
**Location:** `src/mod-ollama-chat_api.cpp`, `QueryOllamaAPI()`  
**Fix Phase:** Not planned (depends on Ollama/model behavior)  

The module sends `"hidethinking": true` alongside `"think": true`. The Ollama documentation for this field is limited and model-dependent. Some models may ignore it. If `hidethinking` is ignored, the model returns raw `<think>...</think>` blocks in the response, which the module detects and returns `""` (bot stays silent). This is handled defensively, but the operator experience (silent bots) may be confusing. **[inferred from api.cpp defensive check]**
