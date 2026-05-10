# Evidence Map

> This document traces every major behavioral claim in the `docs/current-state/` documents back to a specific source file and function. It is the primary traceability index for Phase 0.
>
> **Status labels:** `source-backed` | `inferred` | `unknown`

---

## Module Registration and Startup

| Claim | Evidence | Status |
|-------|----------|--------|
| Module registers scripts via `Addmod_ollama_chatScripts()` | `src/mod-ollama-chat_main.cpp` — function body lists all `new` script registrations | source-backed |
| Config is loaded at server startup via a WorldScript | `src/mod-ollama-chat_config.cpp` — `OllamaChatConfigWorldScript` inherits `WorldScript`; calls `LoadOllamaChatConfig()` on `OnStartup` | source-backed |
| Config is reloaded without restart via `.ollama reload` | `src/mod-ollama-chat_command.cpp` — `HandleOllamaReloadCommand()` calls `sConfigMgr->Reload()` then `LoadOllamaChatConfig()` | source-backed |

---

## Chat Hook Entry Points

| Claim | Evidence | Status |
|-------|----------|--------|
| Player chat enters the module through `OnPlayerCanUseChat` | `src/mod-ollama-chat_handler.h` — `PlayerBotChatHandler` declares 5 overloads of `OnPlayerCanUseChat` with hooks `PLAYERHOOK_CAN_PLAYER_USE_CHAT`, `PLAYERHOOK_CAN_PLAYER_USE_PRIVATE_CHAT`, `PLAYERHOOK_CAN_PLAYER_USE_GROUP_CHAT`, `PLAYERHOOK_CAN_PLAYER_USE_GUILD_CHAT`, `PLAYERHOOK_CAN_PLAYER_USE_CHANNEL_CHAT` | source-backed |
| All 5 overloads call `ProcessChat()` | `src/mod-ollama-chat_handler.cpp` — each overload calls `ProcessChat(player, type, lang, msg, sourceLocal, ...)` | source-backed |
| `ChatChannelSourceLocal` enum maps message types to channels | `src/mod-ollama-chat_handler.h` — enum defined with values 0–17; `src/mod-ollama-chat_handler.cpp` — `GetChannelSourceLocal()` maps `CHAT_MSG_*` constants | source-backed |
| AzerothCore calls the hook before the message is sent | AC hook system convention — the hook name `CAN_PLAYER_USE_CHAT` implies pre-send interception | inferred |

---

## Bot Eligibility and Reply Chances

| Claim | Evidence | Status |
|-------|----------|--------|
| Bots are filtered by distance before receiving a chance to reply | `src/mod-ollama-chat_handler.cpp` — `IsBotEligibleForChatChannelLocal()` checks distance using `g_SayDistance`, `g_YellDistance` | source-backed |
| Reply chances differ by channel type (Say, Party, Guild, Channel) | `src/mod-ollama-chat_config.h` — `g_PlayerReplyChance_Say`, `g_PlayerReplyChance_Party`, `g_PlayerReplyChance_Guild`, `g_PlayerReplyChance_Channel`; `src/mod-ollama-chat_config.cpp` — loaded from conf | source-backed |
| Up to `g_MaxBotsToPick` bots reply per message | `src/mod-ollama-chat_config.h` — `g_MaxBotsToPick`; `src/mod-ollama-chat_handler.cpp` — counter in `ProcessChat()` | source-backed |
| Bots in combat do not reply when `g_DisableRepliesInCombat` is set | `src/mod-ollama-chat_config.h` — `g_DisableRepliesInCombat`; used in bot eligibility check | source-backed |
| Blacklist prefixes prevent bot replies | `src/mod-ollama-chat_config.cpp` — `g_BlacklistCommands` vector populated from conf; `src/mod-ollama-chat_handler.cpp` — message compared against prefixes | source-backed |

---

## Prompt Construction

| Claim | Evidence | Status |
|-------|----------|--------|
| Prompt is built by `GenerateBotPrompt()` | `src/mod-ollama-chat_handler.cpp` — static function `GenerateBotPrompt(Player* bot, std::string playerMessage, Player* player)` | source-backed |
| Prompt uses `g_ChatPromptTemplate` with named placeholders | `src/mod-ollama-chat_config.h` — `g_ChatPromptTemplate`; `src/mod-ollama-chat_handler.cpp` — `SafeFormat()` call with fmt::arg() named args | source-backed |
| Extra info (race, role, faction, zone, distance) uses `g_ChatExtraInfoTemplate` | `src/mod-ollama-chat_config.h` — `g_ChatExtraInfoTemplate`; `src/mod-ollama-chat_handler.cpp` — assembled and injected into main template | source-backed |
| Personality text is injected from `GetPersonalityPromptAddition()` | `src/mod-ollama-chat_personality.h` — function declaration; `src/mod-ollama-chat_personality.cpp` — returns from `g_PersonalityPrompts` map | source-backed |
| Conversation history is injected from `GetBotHistoryPrompt()` | `src/mod-ollama-chat_handler.cpp` — `GetBotHistoryPrompt(botGuid, playerGuid, message)` reads `g_BotConversationHistory` and formats using history templates | source-backed |
| Snapshot context (combat, group, spells, quests) is optionally included | `src/mod-ollama-chat_config.h` — `g_EnableChatBotSnapshotTemplate`; `src/mod-ollama-chat_handler.cpp` — conditional block builds snapshot string | source-backed |
| Sentiment score is optionally included in prompt | `src/mod-ollama-chat_sentiment.h` — `GetBotPlayerSentiment()`; `src/mod-ollama-chat_handler.cpp` — formats using `g_SentimentPromptTemplate` | source-backed |
| RAG info is optionally included in prompt | `src/mod-ollama-chat_config.h` — `g_EnableRAG`, `g_RAGSystem`; `src/mod-ollama-chat_handler.cpp` — calls `g_RAGSystem->RetrieveRelevantInfo()` | source-backed |

---

## LLM API

| Claim | Evidence | Status |
|-------|----------|--------|
| LLM calls use Ollama `/api/generate` | `src/mod-ollama-chat_api.cpp` — `QueryOllamaAPI()` posts to `g_OllamaUrl` which defaults to `http://localhost:11434/api/generate` | source-backed |
| Request body includes `model`, `prompt`, `stream:false` | `src/mod-ollama-chat_api.cpp` — `nlohmann::json requestData = { {"model",...}, {"prompt",...}, {"stream", false} }` | source-backed |
| Optional model parameters only sent if non-default | `src/mod-ollama-chat_api.cpp` — conditional `if (g_OllamaNumPredict > 0)` etc. before adding to `options` object | source-backed |
| Response parsed from `"response"` field in NDJSON | `src/mod-ollama-chat_api.cpp` — `jsonResponse.contains("response")` extraction loop | source-backed |
| `ExtractTextBetweenDoubleQuotes()` strips outer quotes | `src/mod-ollama-chat_api.cpp` — function finds first `"`, extracts to second `"` | source-backed |
| ThinkMode sends `think:true` and `hidethinking:true` | `src/mod-ollama-chat_api.cpp` — `if (g_ThinkModeEnableForModule) { requestData["think"] = true; requestData["hidethinking"] = true; }` | source-backed |
| HTTP client is cpp-httplib | `src/mod-ollama-chat_httpclient.cpp` — `#include <httplib.h>`; uses `httplib::Client` and `httplib::SSLClient` | source-backed |
| HTTPS supported when OpenSSL present | `src/mod-ollama-chat_httpclient.cpp` — `#ifdef CPPHTTPLIB_OPENSSL_SUPPORT` block | source-backed |
| Default HTTP timeout is 120 seconds | `src/mod-ollama-chat_httpclient.cpp` — `OllamaHttpClient::OllamaHttpClient() : m_timeout(120)` | source-backed |

---

## Concurrency

| Claim | Evidence | Status |
|-------|----------|--------|
| LLM calls run on detached `std::thread`s | `src/mod-ollama-chat_querymanager.cpp` — `std::thread(&QueryManager::processQuery, this, prompt, std::move(promise)).detach()` | source-backed |
| Concurrent query count is bounded by `g_MaxConcurrentQueries` | `src/mod-ollama-chat_querymanager.cpp` — `if (maxConcurrentQueries == 0 || currentQueries < maxConcurrentQueries)` | source-backed |
| Excess queries are queued in `taskQueue` | `src/mod-ollama-chat_querymanager.cpp` — `taskQueue.push({ prompt, std::move(promise) })` | source-backed |
| `g_MaxConcurrentQueries` is 0 (unlimited) at `QueryManager` construction | `src/mod-ollama-chat_querymanager.cpp` — constructor reads `g_MaxConcurrentQueries` before config loads; `g_MaxConcurrentQueries` defaults to 0 | source-backed (KI-07) |

---

## Random Chatter

| Claim | Evidence | Status |
|-------|----------|--------|
| Random chatter fires every 30 seconds | `src/mod-ollama-chat_random.cpp` — `static uint32_t timer = 0; if (timer <= diff) { timer = 30000; HandleRandomChatter(); }` | source-backed |
| Random chatter requires a real player within `g_RandomChatterRealPlayerDistance` | `src/mod-ollama-chat_random.cpp` — distance check in `HandleRandomChatter()` | source-backed |
| Per-bot cooldown prevents spam between `g_MinRandomInterval` and `g_MaxRandomInterval` | `src/mod-ollama-chat_random.cpp` — `nextRandomChatTime` map; `urand(g_MinRandomInterval, g_MaxRandomInterval)` | source-backed |
| Environment context (creature, item, spell, etc.) is selected for random chatter | `src/mod-ollama-chat_random.cpp` — `HandleRandomChatter()` enumerates nearby objects and selects context type | source-backed |

---

## Event Chatter

| Claim | Evidence | Status |
|-------|----------|--------|
| 8 distinct game events trigger bot chat | `src/mod-ollama-chat_events.h` — 8 `PlayerScript` subclasses declared | source-backed |
| Event chatter dispatched via `OllamaBotEventChatter::DispatchGameEvent()` | `src/mod-ollama-chat_events.cpp` — static instance `eventChatter`; each event script calls `eventChatter.DispatchGameEvent()` | source-backed |
| Guild events handled separately from proximity events | `src/mod-ollama-chat_events.cpp` — `isGuildEvent` flag checked; guild event types compared against configured strings | source-backed |

---

## Conversation History

| Claim | Evidence | Status |
|-------|----------|--------|
| Bots remember N recent exchanges per player in memory | `src/mod-ollama-chat_config.cpp` — `g_BotConversationHistory` is `unordered_map<uint64_t, unordered_map<uint64_t, deque<pair<string,string>>>>` | source-backed |
| History is bounded by `g_MaxConversationHistory` | `src/mod-ollama-chat_handler.cpp` — `AppendBotConversation()` pops front when deque exceeds limit | source-backed |
| History is periodically flushed to DB | `src/mod-ollama-chat_random.cpp` — `OnUpdate()` calls `SaveBotConversationHistoryToDB()` every `g_ConversationHistorySaveInterval` minutes | source-backed |
| History save uses CTE DELETE that requires MySQL 8.0+ | `src/mod-ollama-chat_handler.cpp` — raw SQL string with `WITH ranked_history AS (...)` | source-backed (KI-04) |

---

## Personality System

| Claim | Evidence | Status |
|-------|----------|--------|
| Personality templates loaded from DB into `g_PersonalityPrompts` | `src/mod-ollama-chat_config.cpp` — `LoadPersonalityTemplatesFromDB()` reads `mod_ollama_chat_personality_templates` | source-backed |
| `manual_only=1` personalities excluded from random assignment | `src/mod-ollama-chat_config.cpp` — `g_PersonalityKeysRandomOnly` populated only with non-manual entries | source-backed |
| New bots are assigned a random personality from `g_PersonalityKeysRandomOnly` | `src/mod-ollama-chat_personality.cpp` — `GetBotPersonality()` selects via `urand()` from this vector | source-backed |
| Personality assignment persisted to `mod_ollama_chat_personality` | `src/mod-ollama-chat_personality.cpp` — `CharacterDatabase.Execute("INSERT INTO mod_ollama_chat_personality ...")` | source-backed (reliability unknown — KI-15) |

---

## Sentiment Tracking

| Claim | Evidence | Status |
|-------|----------|--------|
| Sentiment tracking makes a second synchronous LLM call | `src/mod-ollama-chat_sentiment.cpp` — `AnalyzeMessageSentiment()` calls `QueryOllamaAPI()` directly | source-backed (KI-03) |
| Sentiment value clamped to [0.0, 1.0] | `src/mod-ollama-chat_sentiment.cpp` — `std::max(0.0f, std::min(1.0f, sentimentValue))` | source-backed |
| Sentiment stored in memory under `g_SentimentMutex` | `src/mod-ollama-chat_config.cpp` — `g_BotPlayerSentiments` map and `g_SentimentMutex` declared | source-backed |
| Sentiment disabled by default | `conf/mod_ollama_chat.conf.dist` — `OllamaChat.EnableSentimentTracking = 0` | source-backed |

---

## RAG System

| Claim | Evidence | Status |
|-------|----------|--------|
| RAG uses TF (term frequency) cosine similarity | `src/mod-ollama-chat_rag.cpp` — `TextToTFVector()` and `CalculateCosineSimilarity()` | source-backed |
| RAG loads JSON files from `g_RAGDataPath` | `src/mod-ollama-chat_rag.cpp` — `LoadRAGDataFromDirectory()` iterates `std::filesystem::directory_iterator` | source-backed |
| Each JSON file must be an array of objects with `id` and `content` fields | `src/mod-ollama-chat_rag.cpp` — `LoadRAGDataFromFile()` validates these fields | source-backed |
| RAG disabled by default | `conf/mod_ollama_chat.conf.dist` — `OllamaChat.EnableRAG = 0` | source-backed |

---

## Build System

| Claim | Evidence | Status |
|-------|----------|--------|
| nlohmann/json is bundled | `deps/nlohmann/json.hpp` exists; `mod-ollama-chat.cmake` checks `EXISTS "${CMAKE_CURRENT_LIST_DIR}/deps/nlohmann/json.hpp"` first | source-backed |
| cpp-httplib is bundled | `src/httplib.h` exists; cmake adds `src/` to include path | source-backed |
| OpenSSL is optional at build time | `mod-ollama-chat.cmake` — `find_package(OpenSSL QUIET)` | source-backed |
| No build CI exists (only codestyle check) | `apps/ci/ci-codestyle.sh` is the only CI file in the repository | source-backed |

---

## Claims That Cannot Be Confirmed

| Claim | Reason |
|-------|--------|
| All features work correctly in-game | No in-game test results available in the repository |
| Bot response quality is lore-appropriate | Depends on LLM model and prompt quality — not testable from code |
| Performance is acceptable under concurrent load | No benchmarks available |
| Behavior is correct when Ollama is offline | Error path returns `""` but full server behavior is unknown |
| OpenSSL HTTPS path works on Windows with vcpkg | Build-time dependent; not verified |
| RAG retrieval produces relevant WoW results | Content accuracy of JSON files not verified |
