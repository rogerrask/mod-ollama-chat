# Refactor Roadmap

> This is the primary implementation plan. Each phase is self-contained: it can be handed to a different developer or agent without requiring knowledge of earlier phases beyond what is in the docs.
>
> **No source code changes begin until Phase 0 (documentation) is committed.**

---

## Phase 0 — Documentation Baseline

**Goal:** Capture the current state of the module accurately before any code is touched.

**Status:** In progress (see session memory).

**Definition of Done:**
- [ ] `docs/current-state/` — all files complete with claim labels
- [ ] `docs/design/` — all design files complete
- [ ] `docs/plans/` — all plan files complete
- [ ] `docs/usage/` — all usage files complete
- [ ] evidence-map.md traces all behavioral claims to source
- [ ] behavior-baseline.md distinguishes working / partial / unknown

**Files to create:**
- `docs/README.md` ✅
- `docs/current-state/repository-map.md` ✅
- `docs/current-state/build-system.md` ✅
- `docs/current-state/runtime-flow.md` ✅
- `docs/current-state/llm-api-integration.md` ✅
- `docs/current-state/database-schema.md` ✅
- `docs/current-state/known-issues.md` ✅
- `docs/current-state/configuration.md` ✅
- `docs/current-state/evidence-map.md` ✅
- `docs/current-state/behavior-baseline.md` ✅
- `docs/design/project-goals.md` ✅
- `docs/design/gameplay-experience.md` ✅
- `docs/design/npc-chat-behavior.md` ✅
- `docs/design/wow-3.3.5a-lore-and-world-context.md` ✅
- `docs/design/openai-compatible-endpoints.md` ✅
- `docs/design/prompt-architecture.md` ✅
- `docs/plans/refactor-roadmap.md` ✅ (this file)
- `docs/plans/testing-plan.md`
- `docs/plans/database-migration-plan.md`
- `docs/plans/api-compatibility-plan.md`
- `docs/usage/installation.md`
- `docs/usage/configuration-guide.md`
- `docs/usage/running-with-ollama.md`
- `docs/usage/running-with-openai-compatible-api.md` (stub)
- `docs/usage/testing-in-game.md`
- `docs/usage/troubleshooting.md`

---

## Phase 1 — Low-Risk Cleanup

**Goal:** Fix clear bugs and remove dead code with minimal risk of behavior change.

**Prerequisites:** Phase 0 complete and committed.

**Issues resolved:** KI-07, KI-08, KI-09, KI-10, KI-11, KI-14, KI-15 (partial)

### Tasks

| ID | File | Change |
|----|------|--------|
| 1.1 | `src/mod-ollama-chat-utilities.h` | Confirm `SplitString()` is the canonical version |
| 1.2 | `src/mod-ollama-chat_config.cpp` | Remove duplicate `static SplitString()` definition; use utilities.h version |
| 1.3 | `src/mod-ollama-chat_config.cpp` | Replace raw `g_RAGSystem = new OllamaRAGSystem()` with `std::unique_ptr<OllamaRAGSystem> g_RAGSystem` |
| 1.4 | `src/mod-ollama-chat_config.cpp` | Replace hardcoded `'acore_characters'` in information_schema query with dynamic DB name from `CharacterDatabase.GetDatabaseName()` or configurable key |
| 1.5 | `src/mod-ollama-chat_personality.cpp` | Remove unreachable second `find()` in `GetBotPersonality()` (dead code block) |
| 1.6 | `src/mod-ollama-chat_personality.cpp` | Verify `SetBotPersonality()` INSERT reliability; add error log on DB execute failure |
| 1.7 | `src/mod-ollama-chat_api.cpp` | Remove or convert commented-out `LOG_INFO` debug blocks |
| 1.8 | `src/mod-ollama-chat_querymanager.cpp` | Move `g_MaxConcurrentQueries` read to `setMaxConcurrentQueries()` call in `LoadOllamaChatConfig()` (remove from constructor); initialize internal limit to a safe default (1 or unlimited with a flag) |

### Verification

After Phase 1:
- Module compiles without warnings
- All 12 baseline behaviors (from behavior-baseline.md) still pass manual verification
- No `grep` match for duplicate `SplitString` in `.cpp` files
- `g_RAGSystem` is a `unique_ptr`; valgrind or ASAN shows no leak on reload

---

## Phase 2 — Database and SQL Hardening

**Goal:** Fix SQL correctness and security issues.

**Prerequisites:** Phase 1 complete.

**Issues resolved:** KI-04, KI-05, KI-12

### Tasks

| ID | File | Change |
|----|------|--------|
| 2.1 | `src/mod-ollama-chat_handler.cpp` | Replace CTE DELETE in `SaveBotConversationHistoryToDB()` with compatible DELETE with subquery or row number emulation |
| 2.2 | `src/mod-ollama-chat_handler.cpp` | Parameterize all INSERT/UPDATE SQL using AC's prepared statement API or validated binding; eliminate EscapeString+SafeFormat pattern |
| 2.3 | `data/sql/characters/updates/` | Add migration SQL: `ALTER TABLE mod_ollama_chat_history ADD INDEX IF NOT EXISTS idx_bot_player (bot_guid, player_guid)` |
| 2.4 | `data/sql/characters/updates/` | Add migration SQL for any schema drift identified during Phase 1 review |

### SQL Compatibility Note

`ADD INDEX IF NOT EXISTS` syntax is not universally supported across MySQL and MariaDB versions. The migration SQL must use a conditional pattern. See [database-migration-plan.md](database-migration-plan.md) for the exact compatible syntax.

### Verification

After Phase 2:
- Run `SaveBotConversationHistoryToDB()` logic against a MySQL 5.7 and MariaDB 10.2 test instance
- Verify history trimming works: insert >5 rows, confirm extras are removed
- Run `sqlmap` (or equivalent) on the INSERT logic to confirm no injection surface

---

## Phase 3A — Handler Refactor (God File Split)

**Goal:** Break `mod-ollama-chat_handler.cpp` into focused files.

**Prerequisites:** Phase 2 complete.

**Files to create:**
- `src/mod-ollama-chat_botcontext.cpp/.h` — bot info gathering (spells, group, nearby players)
- `src/mod-ollama-chat_promptbuilder.cpp/.h` — all prompt assembly logic
- `src/mod-ollama-chat_chatrouter.cpp/.h` — bot eligibility, reply decision, channel routing

**Files to reduce:**
- `src/mod-ollama-chat_handler.cpp` — retains only `PlayerBotChatHandler` and `ProcessChat()` (dispatch only)

### Tasks

| ID | Move From | Move To |
|----|----------|---------|
| 3A.1 | `ChatHandler_GetBotSpellInfo()` in handler.cpp | botcontext.cpp |
| 3A.2 | `ChatHandler_GetGroupStatus()` in handler.cpp | botcontext.cpp |
| 3A.3 | `FormatPlayerClass()`, `FormatPlayerRace()` in handler.cpp | botcontext.cpp |
| 3A.4 | `GenerateBotPrompt()` in handler.cpp | promptbuilder.cpp |
| 3A.5 | `GetBotHistoryPrompt()` in handler.cpp | promptbuilder.cpp |
| 3A.6 | `IsBotEligibleForChatChannelLocal()` in handler.cpp | chatrouter.cpp |
| 3A.7 | Deduplicate with `ProcessBotChatMessage()` | chatrouter.cpp |
| 3A.8 | `ExtractTextBetweenDoubleQuotes()` risk | api.cpp — replace with safer trim logic |

### Verification

After Phase 3A:
- All 12 baseline behaviors still pass
- No file in `src/` exceeds 500 lines
- `handler.cpp` retains only `PlayerBotChatHandler` and `ProcessChat()`

---

## Phase 3B — LLM Provider Abstraction

**Goal:** Add `ILLMProvider` interface and implement both `OllamaProvider` and `OpenAICompatibleProvider`.

**Prerequisites:** Phase 3A complete.

**Reference design:** [openai-compatible-endpoints.md](../design/openai-compatible-endpoints.md)

### Tasks

| ID | File | Change |
|----|------|--------|
| 3B.1 | NEW `src/mod-ollama-chat_llmprovider.h` | Define `LLMRequest`, `LLMResponse`, `ILLMProvider` interface |
| 3B.2 | NEW `src/mod-ollama-chat_ollamaprovider.cpp/.h` | `OllamaProvider` wrapping existing `QueryOllamaAPI()` logic |
| 3B.3 | NEW `src/mod-ollama-chat_openaiprovider.cpp/.h` | `OpenAICompatibleProvider` using `/v1/chat/completions` |
| 3B.4 | `src/mod-ollama-chat_config.cpp/.h` | Add `g_LLMProvider` (unique_ptr), `g_OllamaProvider` config key, and OpenAI keys |
| 3B.5 | `src/mod-ollama-chat_querymanager.cpp` | Replace `QueryOllamaAPI()` call with `g_LLMProvider->Complete()` |
| 3B.6 | `src/mod-ollama-chat_api.cpp` | Keep as `OllamaProvider` implementation detail or inline into provider |
| 3B.7 | `conf/mod_ollama_chat.conf.dist` | Add new config keys with comments |
| 3B.8 | `docs/usage/running-with-openai-compatible-api.md` | Fill stub with working examples |
| 3B.9 | `mod-ollama-chat.cmake` | No changes expected (httplib already bundled) |

### Verification

After Phase 3B:
- `Provider = ollama` produces identical results to pre-3B behavior (compare prompt+response pairs)
- `Provider = openai` with Ollama's OpenAI endpoint returns a valid response
- API key does not appear in any log output
- `.ollama reload` switches provider without server restart

---

## Phase 4 — Thread Safety

**Goal:** Replace detached threads with a bounded thread pool; reduce mutex hold times.

**Prerequisites:** Phase 3B complete.

**Issues resolved:** KI-01, KI-02, KI-03 (partial), KI-06

### Tasks

| ID | File | Change |
|----|------|--------|
| 4.1 | `src/mod-ollama-chat_querymanager.cpp` | Replace `std::thread().detach()` with `std::async(std::launch::async, ...)` as transitional fix |
| 4.2 | `src/mod-ollama-chat_querymanager.cpp` | Store `std::future<>` handles; add graceful drain on server shutdown |
| 4.3 | `src/mod-ollama-chat_handler.cpp` | Release `g_ConversationHistoryMutex` before DB write in `SaveBotConversationHistoryToDB()` |
| 4.4 | `src/mod-ollama-chat_api.cpp` | Remove static `OllamaHttpClient` inside `QueryOllamaAPI()`; use provider-owned client that supports `Reconfigure()` |
| 4.5 | `src/mod-ollama-chat_sentiment.cpp` | Queue sentiment analysis via `QueryManager` instead of calling `QueryOllamaAPI()` directly |

**Note:** A proper bounded thread pool is a long-term target. `std::async` is acceptable for Phase 4. The future `std::vector<std::future<>>` drain pattern must handle futures that may already be complete.

### Verification

After Phase 4:
- ASAN/TSAN shows no data races on a test run with concurrent chat
- Server shuts down cleanly with no crashes when LLM calls are in-flight
- History save no longer holds mutex during DB write

---

## Phase 5 — Schema and Migration Polish

**Goal:** Clean up database schema files and ensure migration path is documented.

**Prerequisites:** Phase 2 complete (may run in parallel with Phase 4 if on different developer).

**Issues resolved:** KI-12 (index), migration sequence

### Tasks

| ID | File | Change |
|----|------|--------|
| 5.1 | `data/sql/characters/updates/` | Add index migration file (from Phase 2.3) |
| 5.2 | `data/sql/characters/base/` | Review all 6 base SQL files for consistency |
| 5.3 | `docs/plans/database-migration-plan.md` | Finalize migration plan with exact SQL and compatibility notes |
| 5.4 | `data/sql/characters/` | Add `README.md` explaining base vs. updates distinction |

---

## Phase 6 — Prompt and Lore Quality Pass

**Goal:** Improve default prompt templates and RAG data for WoW 3.3.5a accuracy.

**Prerequisites:** Phase 3A complete.

**Reference:** [wow-3.3.5a-lore-and-world-context.md](../design/wow-3.3.5a-lore-and-world-context.md), [prompt-architecture.md](../design/prompt-architecture.md), [gameplay-experience.md](../design/gameplay-experience.md)

### Tasks

| ID | Area | Change |
|----|------|--------|
| 6.1 | `conf/mod_ollama_chat.conf.dist` | Add explicit instructions in `g_ChatPromptTemplate`: no markdown, no opening with player name, max 2 sentences |
| 6.2 | `conf/mod_ollama_chat.conf.dist` | Review all templates for 3.3.5a accuracy; remove retail WoW references |
| 6.3 | `data/rag/` | Audit all 10 JSON files for 3.3.5a accuracy; update incorrect entries |
| 6.4 | `data/rag/` | Expand RAG coverage: lore characters, zone lore, faction relationships |
| 6.5 | `src/mod-ollama-chat_handler.cpp` | Add prompt token budget check: warn if assembled prompt exceeds NumCtx |
| 6.6 | `conf/mod_ollama_chat.conf.dist` | Document all template placeholders inline in conf file |

---

## Cross-Phase Dependencies

```
Phase 0 (docs)
    ↓
Phase 1 (cleanup)
    ↓
Phase 2 (SQL) ─────────────────────────────────────────┐
    ↓                                                   │
Phase 3A (refactor handler)                         Phase 5 (schema)
    ↓
Phase 3B (providers)
    ↓
Phase 4 (thread safety)
    ↓
Phase 6 (prompts + lore)
```

Phases 2 and 5 can run in parallel. Phase 3A is independent of Phase 2 (different files). Phases 3B and 4 must follow 3A.

---

## Handover Requirements per Phase

Any phase can be picked up by a new developer or agent if they have:
1. This document (`refactor-roadmap.md`)
2. The relevant current-state documents for the files being changed
3. The [behavior-baseline.md](../current-state/behavior-baseline.md) as the regression contract
4. The [known-issues.md](../current-state/known-issues.md) for context on each KI-* reference

No deep knowledge of earlier phases is required if these documents are present and accurate.
