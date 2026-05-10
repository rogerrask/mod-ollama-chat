# Runtime Flow

> **Scope:** Traced from source code. Steps marked **[inferred]** where AzerothCore internals are assumed but not directly read. All other steps are **[source-backed]**.

---

## Overview

The module has three distinct chat activation paths:

| Path | Trigger | Files Involved |
|------|---------|---------------|
| **Flow A** | Player types in chat | `handler.cpp`, `api.cpp`, `querymanager.cpp`, `httpclient.cpp` |
| **Flow B** | Random chatter tick (timer) | `random.cpp`, `handler.cpp`, `api.cpp` |
| **Flow C** | In-game event (kill, loot, death, etc.) | `events.cpp`, `api.cpp` |

All three paths converge at `QueryManager::submitQuery()` → `QueryOllamaAPI()` → `OllamaHttpClient::Post()`.

---

## Flow A: Player Types in Chat → Bot Reply

```
Player types message
        │
        ▼
AzerothCore calls OnPlayerCanUseChat hook  [inferred: AC hook system]
        │
        ▼
PlayerBotChatHandler::OnPlayerCanUseChat()  [source-backed: handler.h]
  (5 overloads: default, Group*, Guild*, Channel*, Player*)
        │
        ▼
GetChannelSourceLocal(type)  [source-backed: handler.cpp]
  Maps CHAT_MSG_SAY → SRC_SAY_LOCAL, CHAT_MSG_WHISPER → SRC_WHISPER_LOCAL, etc.
        │
        ▼
ProcessChat(player, type, lang, msg, sourceLocal, channel, receiver)
  [source-backed: handler.h — static method on PlayerBotChatHandler]
        │
        ├─ Checks g_Enable, g_DisableForSayYell, g_DisableForGuild, etc.
        ├─ Checks g_BlacklistCommands prefix list
        ├─ IsBotEligibleForChatChannelLocal() for each bot:
        │     - Distance checks (g_SayDistance, g_YellDistance)
        │     - Channel membership (group, guild, channel join)
        │     - Faction compatibility [inferred from typical AC patterns]
        │     - Combat state check (g_DisableRepliesInCombat)
        │
        ▼
Per-eligible-bot: reply chance roll
  - Player sender  → g_PlayerReplyChance_Say / _Party / _Guild / _Channel
  - Bot sender     → g_BotReplyChance_Say / _Party / _Guild / _Channel
  Up to g_MaxBotsToPick bots reply per message  [source-backed: config.h]
        │
        ▼
GenerateBotPrompt(bot, playerMessage, player)  [source-backed: handler.cpp]
  ┌─ Assembles prompt string from g_ChatPromptTemplate placeholders:
  │    {bot_name}, {bot_level}, {bot_class}, {bot_personality},
  │    {player_name}, {player_level}, {player_class}, {player_message}
  │
  ├─ Extra info via g_ChatExtraInfoTemplate:
  │    {bot_race}, {bot_gender}, {bot_role}, {bot_faction}, {bot_guild}
  │    {bot_group_status}, {bot_gold}, {player_race}, {player_gender}
  │    {player_role}, {player_faction}, {player_guild}, {bot_area}
  │    {bot_zone}, {bot_map}, {player_distance}
  │
  ├─ Personality: GetPersonalityPromptAddition(personality)  [source-backed: personality.h]
  │    Returns prompt text from g_PersonalityPrompts[key] or g_DefaultPersonalityPrompt
  │
  ├─ Conversation history: GetBotHistoryPrompt(botGuid, playerGuid, message)
  │    Reads g_BotConversationHistory deque (in-memory, bounded by g_MaxConversationHistory)
  │    Formats using g_ChatHistoryHeaderTemplate, g_ChatHistoryLineTemplate, g_ChatHistoryFooterTemplate
  │
  ├─ RAG (if g_EnableRAG):
  │    g_RAGSystem->RetrieveRelevantInfo(message, g_RAGMaxRetrievedItems, g_RAGSimilarityThreshold)
  │    Formatted via GetFormattedRAGInfo(); injected using g_RAGPromptTemplate
  │
  ├─ Bot snapshot (if g_EnableChatBotSnapshotTemplate):
  │    Combat status, group members, known spells, active quests, nearby objects, nearby players
  │    Formatted via g_ChatBotSnapshotTemplate
  │
  └─ Sentiment (if g_EnableSentimentTracking):
       GetBotPlayerSentiment(botGuid, playerGuid) → float 0.0–1.0
       Formatted via g_SentimentPromptTemplate
        │
        ▼
g_queryManager.submitQuery(prompt)  [source-backed: api.h]
  Returns std::future<std::string>
        │
        ▼
QueryManager::submitQuery()  [source-backed: querymanager.cpp]
  ┌─ If currentQueries < maxConcurrentQueries (or no limit):
  │    Increment currentQueries
  │    Launch std::thread(&QueryManager::processQuery, ...).detach()  ← KNOWN ISSUE KI-01
  └─ Else: push to taskQueue (std::queue<QueryTask>)
        │
        ▼
QueryManager::processQuery() [on detached thread]  [source-backed: querymanager.cpp]
        │
        ▼
QueryOllamaAPI(prompt)  [source-backed: api.cpp]
  ┌─ Constructs JSON request body:
  │    { "model": g_OllamaModel,
  │      "prompt": SanitizeUTF8(prompt),
  │      "stream": false,
  │      "options": { num_predict, temperature, top_p, repeat_penalty, num_ctx, num_thread }
  │               (only fields that differ from defaults are sent)
  │      "stop": [...] (if g_OllamaStop set)
  │      "system": g_OllamaSystemPrompt (if set)
  │      "think": true, "hidethinking": true (if g_ThinkModeEnableForModule) }
  │
  ├─ OllamaHttpClient::Post(g_OllamaUrl, requestJson)  [source-backed: httpclient.cpp]
  │    URL parsed by regex; selects httplib::Client or httplib::SSLClient
  │    Sets connection/read/write timeout (120s default)
  │    Adds ngrok bypass header if host contains "ngrok"
  │
  ├─ Response parsing:
  │    Reads NDJSON lines; accumulates jsonResponse["response"] strings
  │    (stream:false means Ollama still returns NDJSON with one line containing full response)
  │
  ├─ ExtractTextBetweenDoubleQuotes(): strips surrounding quote marks if response is quoted
  │    NOTE: strips to first double-quoted substring — may strip valid content  [inferred risk, KI-13]
  │
  ├─ ThinkMode guard: if <think> or </think> found in response → return ""
  └─ Returns plain text string (or "" on any error)
        │
        ▼
Future result retrieved in ProcessChat  [source-backed: handler.cpp — inferred from future.get() pattern]
        │
        ▼
Bot sends reply in appropriate channel  [source-backed: handler.cpp]
  - Say/Yell: bot->Say() / bot->Yell()  [inferred: AC Player API]
  - Party: bot sends to group chat  [inferred]
  - Guild: bot sends to guild chat  [inferred]
  - Whisper: bot whispers back to player  [inferred]
  - Channel: bot sends to named channel  [inferred]
        │
        ▼
AppendBotConversation(botGuid, playerGuid, playerMessage, botReply)
  Pushes {playerMessage, botReply} pair to g_BotConversationHistory[bot][player] deque
  Pops front if deque exceeds g_MaxConversationHistory  [source-backed: handler.cpp]
        │
        ▼ (periodic — every g_ConversationHistorySaveInterval minutes)
SaveBotConversationHistoryToDB()  [source-backed: random.cpp OnUpdate trigger]
  Holds g_ConversationHistoryMutex across all CharacterDatabase.Execute() calls  ← KI-02
  INSERT IGNORE into mod_ollama_chat_history
  CTE-based DELETE to trim old rows  ← KI-04 (MySQL 8.0+ only)
```

---

## Flow B: Random Chatter Tick

```
OllamaBotRandomChatter::OnUpdate(uint32 diff)
  Called every server world update tick  [source-backed: random.h WorldScript]
        │
        ├─ Periodic history save check (every g_ConversationHistorySaveInterval minutes)
        ├─ Periodic sentiment save check (every g_SentimentSaveInterval minutes)
        │
        ▼
static uint32 timer = 0; timer -= diff;
When timer expires (30,000ms / 30 seconds): HandleRandomChatter()  [source-backed: random.cpp]
Timer resets to 30,000ms after each fire.
        │
        ▼
HandleRandomChatter()  [source-backed: random.cpp]
  Iterates ObjectAccessor::GetPlayers()
  Separates real players from bots (via PlayerbotsMgr::instance().GetPlayerbotAI())
        │
  For each bot:
    ├─ Skip if not InWorld or IsBeingTeleported
    ├─ Skip if in combat and g_DisableRepliesInCombat
    ├─ Check nextRandomChatTime[botGuid] — skip if not yet due
    ├─ Check real player within g_RandomChatterRealPlayerDistance
    ├─ Roll g_RandomChatterBotCommentChance (0–100)
    │
    ├─ Select environment context (one of):
    │    nearby creature name, nearby game object, equipped item,
    │    bag item, known spell, quest area, vendor NPC, questgiver NPC,
    │    bag slot count, dungeon name, unfinished quest name
    │
    ├─ Build prompt from g_RandomChatterPromptTemplate with env placeholders
    │    Randomly selects one variation from g_RandomChatterPromptVariations
    │    OR one question from g_RandomChatterQuestionVariations
    │
    └─ Submit to QueryManager → QueryOllamaAPI() (same as Flow A from here)
         Set nextRandomChatTime[botGuid] = now + rand(g_MinRandomInterval, g_MaxRandomInterval)
```

---

## Flow C: Event Chatter

```
Game event fires (AzerothCore hook)  [inferred: AC hook system]
  e.g., OnPlayerCreatureKill, OnPlayerStoreNewItem, OnPlayerJustDied, etc.
        │
        ▼
Event PlayerScript hook (ChatOnKill, ChatOnLoot, etc.)  [source-backed: events.h]
        │
        ▼
OllamaBotEventChatter::DispatchGameEvent(source, eventType, eventDetail)
  [source-backed: events.cpp]
        │
        ├─ Check g_Enable and g_EnableEventChatter
        ├─ Check g_EventType<X>_Chance roll for this event type
        │
        ├─ Guild event check: if source is in guild + g_EnableGuildEventChatter
        │    and event type is guild-relevant → isGuildEvent = true
        │    Check for real guild member online
        │
        ├─ Real player proximity check (g_EventChatterRealPlayerDistance)
        │    Source bot: skip if no real player nearby AND not a guild event
        │
        ▼
QueueEvent(bot, type, detail, actorName, isGuildEvent)
  For each eligible bot within range:
    Roll g_EventChatterBotCommentChance (or g_EventChatterBotSelfCommentChance for self-events)
    Up to g_EventChatterMaxBotsPerPlayer bots respond
        │
        ▼
BuildPrompt(bot, promptTemplate, eventType, eventDetail, actorName)
  Fills g_EventChatterPromptTemplate placeholders:
    {bot_name}, {bot_level}, {bot_class}, {bot_race}, {bot_gender}
    {bot_role}, {bot_faction}, {bot_area}, {bot_zone}, {bot_map}
    {bot_personality}, {bot_personality_name}, {event_type}, {event_detail}
    {actor_name}, {sentiment_info}
        │
        ▼
Async LLM call (same QueryManager → QueryOllamaAPI path as Flow A)
        │
        ▼
Bot sends reply in appropriate channel
  Guild events → guild chat
  Non-guild events → say/party based on bot's channel context  [inferred]
```

---

## Sentiment Update (Side Effect of Flow A)

When `g_EnableSentimentTracking` is true, `UpdateBotPlayerSentiment()` is called during Flow A: **[source-backed: sentiment.cpp]**

```
UpdateBotPlayerSentiment(bot, player, playerMessage)
        │
        ▼
AnalyzeMessageSentiment(playerMessage)  ← SYNCHRONOUS LLM CALL on calling thread  KI-03
  Calls QueryOllamaAPI() with g_SentimentAnalysisPrompt
  Parses "POSITIVE" / "NEGATIVE" / "NEUTRAL" from response
  Returns ±g_SentimentAdjustmentStrength or 0.0
        │
        ▼
SetBotPlayerSentiment(botGuid, playerGuid, clamp(current + adjustment, 0.0, 1.0))
  Stores in g_BotPlayerSentiments map under mutex
```

---

## Config Reload Flow

```
Player or console: .ollama reload  (or: ollama reload)
        │
        ▼
OllamaChatConfigCommand::HandleOllamaReloadCommand()  [source-backed: command.cpp]
        │
        ├─ sConfigMgr->Reload()  — reloads the .conf file
        ├─ LoadOllamaChatConfig()  — repopulates all g_* globals
        ├─ ClearAllBotPersonalities() (if !g_EnableRPPersonalities)
        ├─ LoadBotPersonalityList()  — re-reads personality DB table
        ├─ LoadBotConversationHistoryFromDB()  — re-reads history from DB
        └─ InitializeSentimentTracking()  — re-reads sentiment from DB

NOTE: The static OllamaHttpClient inside QueryOllamaAPI() is NOT reset.
URL or timeout changes require a server restart to take effect.  [source-backed — KI-06]
```
