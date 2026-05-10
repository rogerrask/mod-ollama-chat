# Behavior Baseline

> This document records what is known to work, what is partially verified, and what is unknown about the module's current behavior. It is based on static code review only. No in-game testing has been performed unless explicitly noted.
>
> **This is the "before" snapshot.** Its purpose is to establish what behavior must be preserved as the refactor proceeds. Any regression against this baseline is a bug.

---

## KNOWN WORKING

*Code paths are complete, logic is sound from review. These features should work on a correctly configured server.*

| Feature | Evidence |
|---------|----------|
| Config loads from `.conf` file on server start | `OllamaChatConfigWorldScript::OnStartup()` → `LoadOllamaChatConfig()` reads all keys via `sConfigMgr->GetOption<>()` |
| Config can be reloaded without server restart | `.ollama reload` → `HandleOllamaReloadCommand()` calls `sConfigMgr->Reload()` then `LoadOllamaChatConfig()` |
| 5 `OnPlayerCanUseChat` hook overloads registered | `PlayerBotChatHandler` constructor registers hooks for private, group, guild, channel, and default chat |
| `CHAT_MSG_*` types mapped to `ChatChannelSourceLocal` enum | `GetChannelSourceLocal()` covers Say, Yell, Party, Raid, Guild, Officer, Whisper, Channel |
| Message blacklist prefix filtering | `g_BlacklistCommands` vector checked against message start; default list is extensive |
| Per-channel reply chance rolled per eligible bot | `g_PlayerReplyChance_Say/Party/Guild/Channel` and equivalent bot-to-bot chances |
| Max bots per message enforced | Counter in `ProcessChat()` stops after `g_MaxBotsToPick` |
| 8 event hooks registered | `ChatOnKill`, `ChatOnLoot`, `ChatOnDeath`, `ChatOnQuest`, `ChatOnLearn`, `ChatOnDuel`, `ChatOnLevelUp`, `ChatOnAchievement`, `ChatOnGameObjectUse` all registered in `main.cpp` |
| Random chatter tick every 30 seconds | `static uint32_t timer = 30000` decremented in `OnUpdate()`; `HandleRandomChatter()` called on expiry |
| Per-bot random chat cooldown | `nextRandomChatTime` map; random interval between `g_MinRandomInterval` and `g_MaxRandomInterval` |
| Combat reply suppression | `g_DisableRepliesInCombat` checked in eligibility logic |
| HTTP POST request to Ollama `/api/generate` constructed correctly | `QueryOllamaAPI()` builds valid `nlohmann::json` body with all documented fields |
| `stream: false` sent to Ollama | Hardcoded in request body |
| Model parameters only sent when non-default | Conditional checks before adding to `options{}` object |
| NDJSON response parsed and `"response"` field extracted | Loop over lines, `jsonResponse["response"]` accumulation |
| Error returns `""` on any HTTP or parse failure | Multiple `return ""` paths in `QueryOllamaAPI()` |
| Conversation history bounded in memory | `AppendBotConversation()` pops front when deque size exceeds `g_MaxConversationHistory` |
| History flushed periodically | `OnUpdate()` checks elapsed time against `g_ConversationHistorySaveInterval` |
| Personality templates loaded from DB into map | `LoadPersonalityTemplatesFromDB()` reads `mod_ollama_chat_personality_templates` |
| `manual_only=1` entries excluded from random assignment | Separate `g_PersonalityKeysRandomOnly` vector populated conditionally |
| RAG JSON files loaded from configured directory | `OllamaRAGSystem::Initialize()` → `LoadRAGDataFromDirectory()` iterates `.json` files |
| RAG disabled by default | `OllamaChat.EnableRAG = 0` in conf.dist |
| Sentiment tracking disabled by default | `OllamaChat.EnableSentimentTracking = 0` in conf.dist |
| `.ollama sentiment view/set/reset` commands functional | Command handlers implemented with `ObjectAccessor::FindPlayer()` and direct map access |
| `.ollama personality get/set/list` commands functional | Command handlers implemented with DB read/write and map lookup |
| UTF-8 sanitization applied to prompt before sending | `SanitizeUTF8()` called in `QueryOllamaAPI()` before JSON construction |
| Guild event chatter checks for real guild members online | `DispatchGameEvent()` iterates `ObjectAccessor::GetPlayers()` for guild membership |

---

## PARTIALLY VERIFIED

*Code path is present and logically complete, but behavior has a known issue, untested edge case, or compatibility risk.*

| Feature | Status | Issue |
|---------|--------|-------|
| Conversation history DB persistence | Code present; INSERT works; cleanup DELETE fails on MySQL 5.7 / MariaDB < 10.2.1 | KI-04 |
| History INSERT uses EscapeString pattern | Code present; not parameterized — injection surface remains | KI-05 |
| Sentiment tracking analysis | Code present; second synchronous LLM call blocks calling thread when enabled | KI-03 |
| ThinkMode response handling | `think:true` sent; `hidethinking:true` sent; whether Ollama actually strips think blocks depends on model | KI-16 |
| Personality DB persistence on new bot assignment | Code present; `information_schema` check hardcodes DB name; INSERT may fail silently | KI-11, KI-15 |
| Channel-specific reply logic (Party, Guild, Channel) | Code path present for each; exact behavior under all channel states not verified | unknown |
| Bot snapshot context (combat, group, spells, quests) | Code present; context gathering functions complete; prompt injection conditional on `g_EnableChatBotSnapshotTemplate` | unknown in-game |
| Config reload effect on HTTP client URL | URL re-read from `g_OllamaUrl` on each `Post()` call — URL changes work; timeout changes require restart | KI-06 |
| Random chatter prompt variation selection | Pipe-split loading and random selection code present; in-game variation quality unknown | unknown |
| RAG similarity retrieval | TF cosine similarity implemented; retrieval quality for WoW content queries unknown | unknown |
| `ExtractTextBetweenDoubleQuotes` stripping | Function present; risk of stripping mid-sentence quoted content | KI-13 |
| Typing simulation delay | Code present; delay applied before bot sends message; actual timing accuracy unverified | unknown |

---

## UNKNOWN / NOT VERIFIED

*Cannot be confirmed from code review alone. Requires in-game testing or external verification.*

| Feature / Question | Why Unknown |
|-------------------|-------------|
| Whether any feature has been tested end-to-end on a live server | No test logs, screenshots, or reports in the repository |
| Bot reply quality in plain WoW context | Depends on model choice, prompt quality, and player input — not testable from code |
| Lore accuracy of bot responses for WoW 3.3.5a | Depends on LLM training data and RAG content — requires in-game testing with a knowledgeable player |
| Performance under concurrent chat load (many bots + fast chat) | No benchmarks; detached threads mean unbounded thread creation (KI-01) |
| Behavior when Ollama endpoint is unreachable | Error paths return `""` (bot stays silent); server stability unconfirmed |
| Behavior when Ollama endpoint is very slow (>60s) | 120s timeout exists; thread behavior during long wait unconfirmed |
| Whether HTTPS endpoint works on Windows with vcpkg OpenSSL | Build and runtime behavior not confirmed |
| Whether HTTPS endpoint works on Linux | Not confirmed, though code path exists |
| RAG retrieval relevance for actual WoW player messages | JSON content accuracy and query-to-content matching quality unknown |
| Whisper reply behavior (`g_EnableWhisperReplies = 0` default) | Whisper path exists in code; not tested with enabled setting |
| Effect of `g_MaxConcurrentQueries` configured limit | Value is always 0 at QueryManager construction (KI-07); configured limit may never apply |
| Guild random ambient chatter behavior | Code path present; never triggered in known test environment |
| Whether `bot_snapshot` context meaningfully improves response quality | Disabled by default; never tested |
| Whether sentiment adjustment values produce believable behavior over time | Requires extended play session to evaluate |
| Behavior on server shutdown with in-flight LLM queries | Detached threads continue running; crash risk unconfirmed (KI-01) |

---

## Baseline Contract for Refactoring

The following behaviors must be preserved exactly through all refactoring phases:

1. Bots respond to player chat in Say, Yell, Party, Guild, Channel, and Whisper channels
2. Reply chance is per-channel and per-message-source (player vs. bot)
3. Up to `g_MaxBotsToPick` bots respond per message
4. Blacklist prefixes prevent bot replies
5. Bots do not reply in combat when `g_DisableRepliesInCombat` is set
6. Random chatter fires approximately every 30 seconds per bot when a real player is nearby
7. Event chatter fires on the 8 registered game events
8. Conversation history accumulates in memory and is bounded
9. Config reload via `.ollama reload` applies changes without restart
10. All commands under `.ollama` tree remain functional
11. Module is silent (returns `""`) on any LLM API error
12. Module loads and starts without error when all 4 DB tables exist

Any change that breaks any of the above is a regression regardless of which phase introduced it.
