# Repository Map

> **Scope:** Repository as it exists on the `main` branch, reviewed May 2026.
> All claims are **[source-backed]** unless marked **[inferred]** or **[unknown]**.

---

## Top-Level Files

| File | Description |
|------|-------------|
| `LICENSE` | MIT license |
| `README.md` | End-user README: features, install steps, Ollama setup, command reference |
| `mod-ollama-chat.cmake` | CMake build script; links dependencies and platform libs against the AC `modules` target |
| `include.sh` | Shell include helper used by the AzerothCore module loader **[inferred — not read in detail]** |
| `PERSONALITY_COMMANDS.md` | Operator reference for in-game personality commands |
| `RAG_DOCUMENTATION.md` | Operator reference for the RAG system configuration |
| `SENTIMENT_TRACKING_DOCUMENTATION.md` | Operator reference for the sentiment tracking system |

---

## `src/` — C++ Source Files

### Entry Point

| File | Class / Function | Role |
|------|-----------------|------|
| `mod-ollama-chat_main.cpp` | `Addmod_ollama_chatScripts()` | Registers all scripts with AzerothCore on server load **[source-backed: main.cpp]** |

Scripts registered in `Addmod_ollama_chatScripts()`:
- `OllamaChatConfigWorldScript` (from `_config.h`)
- `PlayerBotChatHandler` (from `_handler.h`)
- `OllamaBotRandomChatter` (from `_random.h`)
- `ChatOnKill`, `ChatOnLoot`, `ChatOnDeath`, `ChatOnQuest`, `ChatOnLearn`, `ChatOnDuel`, `ChatOnLevelUp`, `ChatOnAchievement`, `ChatOnGameObjectUse` (from `_events.h`)
- `OllamaChatConfigCommand` (from `_command.h`)

### Chat Handler

| File | Class / Key Symbols | Role |
|------|-------------------|------|
| `mod-ollama-chat_handler.h` | `PlayerBotChatHandler`, `ChatChannelSourceLocal` enum, `ProcessChat()` | Public interface for chat routing **[source-backed]** |
| `mod-ollama-chat_handler.cpp` | `ProcessChat()`, `IsBotEligibleForChatChannelLocal()`, `GenerateBotPrompt()`, `ProcessBotChatMessage()`, `AppendBotConversation()`, `SaveBotConversationHistoryToDB()`, `GetBotHistoryPrompt()`, `ChatHandler_GetBotSpellInfo()`, `ChatHandler_GetGroupStatus()` | Primary chat routing, prompt construction, conversation history, and bot context gathering **[source-backed]** |

`handler.cpp` is the largest file in the module and contains several distinct responsibilities (routing, prompt building, context gathering, history management). This is a known architectural issue — see [known-issues.md](known-issues.md) and [plans/refactor-roadmap.md](../plans/refactor-roadmap.md) Phase 3.

`ChatChannelSourceLocal` enum values **[source-backed: handler.h]**:

| Value | Integer | Meaning |
|-------|---------|---------|
| `SRC_UNDEFINED_LOCAL` | 0 | Unknown/unmapped |
| `SRC_SAY_LOCAL` | 1 | /say |
| `SRC_PARTY_LOCAL` | 2 | /party |
| `SRC_RAID_LOCAL` | 3 | /raid |
| `SRC_GUILD_LOCAL` | 4 | /guild |
| `SRC_OFFICER_LOCAL` | 5 | /officer |
| `SRC_YELL_LOCAL` | 6 | /yell |
| `SRC_WHISPER_LOCAL` | 7 | /whisper |
| `SRC_GENERAL_LOCAL` | 17 | Custom channels (General, Trade, etc.) |

### Event Chatter

| File | Class / Key Symbols | Role |
|------|-------------------|------|
| `mod-ollama-chat_events.h` | `OllamaBotEventChatter`, `ChatOnKill`, `ChatOnLoot`, `ChatOnDeath`, `ChatOnQuest`, `ChatOnLearn`, `ChatOnDuel`, `ChatOnLevelUp`, `ChatOnAchievement`, `ChatOnGameObjectUse` | 8 PlayerScript subclasses, each hooking a game event **[source-backed: events.h]** |
| `mod-ollama-chat_events.cpp` | `DispatchGameEvent()`, `QueueEvent()`, `BuildPrompt()` | Event dispatch, bot selection, prompt building for event-triggered chat **[source-backed]** |

### Random Chatter

| File | Class / Key Symbols | Role |
|------|-------------------|------|
| `mod-ollama-chat_random.h` | `OllamaBotRandomChatter` (WorldScript) | `OnUpdate()` tick for periodic random bot chat **[source-backed: random.h]** |
| `mod-ollama-chat_random.cpp` | `HandleRandomChatter()`, `nextRandomChatTime` map | Per-bot timer management, player proximity checks, environment context selection **[source-backed]** |

### Configuration

| File | Class / Key Symbols | Role |
|------|-------------------|------|
| `mod-ollama-chat_config.h` | 200+ `extern` global declarations | Exposes all runtime config variables to other translation units **[source-backed]** |
| `mod-ollama-chat_config.cpp` | All global definitions, `LoadOllamaChatConfig()`, `LoadBotPersonalityList()`, `OllamaChatConfigWorldScript` | Loads `.conf` values into globals on server start and on `.ollama reload` **[source-backed]** |

`OllamaChatConfigWorldScript` is a WorldScript that calls `LoadOllamaChatConfig()` during `OnStartup`. **[source-backed: config.cpp]**

### LLM API Layer

| File | Class / Key Symbols | Role |
|------|-------------------|------|
| `mod-ollama-chat_api.h` | `QueryOllamaAPI()`, `SubmitQuery()`, `g_queryManager` | Public API entry points for LLM queries **[source-backed: api.h]** |
| `mod-ollama-chat_api.cpp` | `QueryOllamaAPI()`, `ExtractTextBetweenDoubleQuotes()` | Builds JSON request, calls HTTP client, parses NDJSON response **[source-backed]** |
| `mod-ollama-chat_querymanager.h` | `QueryManager` class | Concurrency-limited query submission with internal queue **[source-backed]** |
| `mod-ollama-chat_querymanager.cpp` | `submitQuery()`, `processQuery()` | Dispatches queries on detached `std::thread`s **[source-backed]** |
| `mod-ollama-chat_httpclient.h` | `OllamaHttpClient` | HTTP/HTTPS POST interface **[source-backed]** |
| `mod-ollama-chat_httpclient.cpp` | `Post()` | URL parsing, HTTP/HTTPS client selection via cpp-httplib, ngrok header injection **[source-backed]** |

### Personality System

| File | Class / Key Symbols | Role |
|------|-------------------|------|
| `mod-ollama-chat_personality.h` | `GetBotPersonality()`, `SetBotPersonality()`, `GetPersonalityPromptAddition()`, `ClearAllBotPersonalities()` | Bot personality assignment and lookup **[source-backed]** |
| `mod-ollama-chat_personality.cpp` | Full implementations; DB read/write for per-bot personality | Assigns random personality from pool to new bots; persists to `mod_ollama_chat_personality` **[source-backed]** |

### Sentiment Tracking

| File | Class / Key Symbols | Role |
|------|-------------------|------|
| `mod-ollama-chat_sentiment.h` | `GetBotPlayerSentiment()`, `SetBotPlayerSentiment()`, `AnalyzeMessageSentiment()`, `UpdateBotPlayerSentiment()`, `SaveBotPlayerSentimentsToDB()`, `InitializeSentimentTracking()` | Per-bot-player relationship score (0.0–1.0) **[source-backed]** |
| `mod-ollama-chat_sentiment.cpp` | All implementations; synchronous LLM call for sentiment analysis | Analyzes message via separate LLM call; clamps and stores sentiment float **[source-backed]** |

### RAG System

| File | Class / Key Symbols | Role |
|------|-------------------|------|
| `mod-ollama-chat_rag.h` | `OllamaRAGSystem`, `RAGEntry`, `RAGResult` | Retrieval-Augmented Generation using TF cosine similarity **[source-backed]** |
| `mod-ollama-chat_rag.cpp` | `Initialize()`, `LoadRAGDataFromDirectory()`, `RetrieveRelevantInfo()`, `CalculateCosineSimilarity()`, `TextToTFVector()` | Loads JSON knowledge files; retrieves top-N entries by cosine similarity to query **[source-backed]** |

### Commands

| File | Class / Key Symbols | Role |
|------|-------------------|------|
| `mod-ollama-chat_command.h` | `OllamaChatConfigCommand` (CommandScript) | In-game `.ollama` command tree **[source-backed]** |
| `mod-ollama-chat_command.cpp` | `HandleOllamaReloadCommand()`, `HandleOllamaSentimentViewCommand()`, `HandleOllamaSentimentSetCommand()`, `HandleOllamaSentimentResetCommand()`, `HandleOllamaPersonalityGetCommand()`, `HandleOllamaPersonalitySetCommand()`, `HandleOllamaPersonalityListCommand()` | GM-level commands for reload, sentiment management, personality management **[source-backed]** |

Command tree **[source-backed: command.cpp]**:
```
.ollama reload
.ollama sentiment view [bot] [player]
.ollama sentiment set <bot> <player> <value>
.ollama sentiment reset <bot> <player>
.ollama personality get <bot>
.ollama personality set <bot> <personality>
.ollama personality list
```
All commands require `SEC_ADMINISTRATOR`. **[source-backed: command.cpp]**

### Utilities

| File | Key Symbols | Role |
|------|------------|------|
| `mod-ollama-chat-utilities.h` | `SafeFormat()`, `SplitString()`, `SanitizeUTF8()` | Header-only helpers used across all translation units **[source-backed]** |

Note: A `static SplitString` also exists in `mod-ollama-chat_config.cpp` — this is a duplicate. **[source-backed — known issue KI-08]**

---

## `deps/` — Bundled Dependencies

| Path | Library | Notes |
|------|---------|-------|
| `deps/nlohmann/json.hpp` | nlohmann/json v3.x | Single-header JSON library; bundled to avoid system dependency **[source-backed: cmake]** |
| `src/httplib.h` | cpp-httplib | Single-header HTTP/HTTPS client; bundled in `src/` **[source-backed: cmake]** |

---

## `data/` — Data Files

### `data/sql/characters/base/` — Database Migrations

| File | Purpose |
|------|---------|
| `2025_03_30_personalities.sql` | Initial personality table (superseded — used `INT guid`) |
| `2025_05_30_personalities.sql` | Revised personality table (`BIGINT guid`, `VARCHAR(64) personality`) |
| `2025_05_31_personality_template.sql` | Creates `mod_ollama_chat_personality_templates` with seed data |
| `2025_06_14_chat_history.sql` | Creates `mod_ollama_chat_history` |
| `2025_07_24_sentiment_tracking.sql` | Creates `mod_ollama_chat_bot_player_sentiments` |
| `2025_11_01_personality_manual_only.sql` | Adds `manual_only` column to personality templates |

All source-backed from SQL files. Apply in date order. The `updates/` subdirectory exists but is empty. **[source-backed]**

### `data/rag/` — RAG Knowledge Base

10 JSON files covering WoW 3.3.5a content **[source-backed: directory listing]**:

| File | Content |
|------|---------|
| `wow_classes_factions.json` | Class and faction data |
| `wow_dungeons_raids.json` | Dungeon and raid reference |
| `wow_general_tips.json` | General gameplay tips |
| `wow_items_equipment.json` | Item and equipment information |
| `wow_mechanics.json` | Game mechanics reference |
| `wow_npcs_creatures.json` | NPC and creature data |
| `wow_professions.json` | Profession information |
| `wow_pvp.json` | PvP reference |
| `wow_quests_storylines.json` | Quest and story data |
| `wow_zones.json` | Zone reference |

The accuracy and completeness of these files for WotLK 3.3.5a content has not been verified. **[unknown]**

---

## `conf/`

| File | Purpose |
|------|---------|
| `mod_ollama_chat.conf.dist` | Distributable config template with all keys, types, defaults, and documentation comments |

---

## `apps/ci/`

| File | Purpose |
|------|---------|
| `ci-codestyle.sh` | Codestyle check script; the only CI currently in the repository **[source-backed]** |

No build verification CI exists. **[source-backed — known issue]**

---

## Class Hierarchy Summary

```
WorldScript
  └─ OllamaChatConfigWorldScript    [config.cpp — loads config on startup]
  └─ OllamaBotRandomChatter         [random.cpp — 30s tick for random chat]

PlayerScript
  └─ PlayerBotChatHandler           [handler.cpp — all OnPlayerCanUseChat hooks]
  └─ ChatOnKill                     [events.cpp]
  └─ ChatOnLoot                     [events.cpp]
  └─ ChatOnDeath                    [events.cpp]
  └─ ChatOnQuest                    [events.cpp]
  └─ ChatOnLearn                    [events.cpp]
  └─ ChatOnDuel                     [events.cpp]
  └─ ChatOnLevelUp                  [events.cpp]
  └─ ChatOnAchievement              [events.cpp]
  └─ ChatOnGameObjectUse            [events.cpp]

CommandScript
  └─ OllamaChatConfigCommand        [command.cpp — .ollama command tree]

Plain classes (not registered as scripts):
  OllamaBotEventChatter             [events.cpp — event dispatch helper]
  QueryManager                      [querymanager.cpp — concurrency control]
  OllamaHttpClient                  [httpclient.cpp — HTTP abstraction]
  OllamaRAGSystem                   [rag.cpp — retrieval system]
```
