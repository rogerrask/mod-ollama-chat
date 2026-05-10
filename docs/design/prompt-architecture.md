# Prompt Architecture

> **Scope:** How prompts are built for each interaction type. This is a description of current behavior plus design intent for improvement. Claims about current behavior are [source-backed] unless noted.

---

## Overview

Every bot message requires a prompt sent to the LLM. Prompts are assembled from multiple template strings, each injected with runtime values using `SafeFormat()` (a wrapper around `fmt::vformat`).

There are three distinct prompt construction paths:

| Path | Entry Point | Key Template |
|------|-------------|-------------|
| Player reply | `GenerateBotPrompt()` | `g_ChatPromptTemplate` |
| Random chatter | `HandleRandomChatter()` | `g_RandomChatterPromptTemplate` |
| Event chatter | `OllamaBotEventChatter::BuildPrompt()` | `g_EventChatterPromptTemplate` |

---

## Player Reply Prompt Construction

**[source-backed]** — `src/mod-ollama-chat_handler.cpp` `GenerateBotPrompt()`

### Components (assembled in order)

```
[SystemPrompt]          ← g_OllamaSystemPrompt (sent as Ollama "system" field)
[ChatPromptTemplate]    ← g_ChatPromptTemplate with:
  {bot_name}            ← bot->GetName()
  {bot_level}           ← bot->GetLevel()
  {bot_class}           ← FormatPlayerClass(bot)
  {bot_personality}     ← GetPersonalityPromptAddition(botGuid)
  {bot_personality_name} ← personality key string
  {player_name}         ← player->GetName()
  {player_level}        ← player->GetLevel()
  {player_class}        ← FormatPlayerClass(player)
  {player_message}      ← sanitized incoming message
  {extra_info}          ← ChatExtraInfoTemplate (see below)
  {chat_history}        ← GetBotHistoryPrompt() (see below)
  {sentiment_info}      ← SentimentPromptTemplate (if enabled)
  {rag_info}            ← RAGPromptTemplate (if enabled)
```

### ChatExtraInfoTemplate

Injected into `{extra_info}`:
```
{bot_race}
{bot_gender}
{bot_role}
{bot_faction}
{bot_guild}
{bot_group_status}
{bot_gold}
{player_race}
{player_gender}
{player_role}
{player_faction}
{player_guild}
{player_group_status}
{player_gold}
{player_distance}
{bot_area}
{bot_zone}
{bot_map}
```

### Snapshot Context (optional)

When `g_EnableChatBotSnapshotTemplate = 1`, an additional block is assembled and injected using `g_ChatBotSnapshotTemplate`:
```
{combat}        ← "in combat" or "not in combat"
{group}         ← group status summary from ChatHandler_GetGroupStatus()
{spells}        ← top spells from ChatHandler_GetBotSpellInfo()
{quests}        ← active quest list (up to N quests)
{los}           ← nearby objects with LoS (creatures, gameobjects)
{players}       ← nearby player names
```

### Conversation History

When `g_EnableChatHistory = 1`, `GetBotHistoryPrompt()` formats up to `g_MaxConversationHistory` pairs using:
- `g_ChatHistoryHeaderTemplate` — prepended once
- `g_ChatHistoryLineTemplate` for each exchange (`{sender}`, `{message}`, `{timestamp}`)
- `g_ChatHistoryFooterTemplate` — appended once

### Sentiment Context

When `g_EnableSentimentTracking = 1`, `g_SentimentPromptTemplate` is formatted with:
- `{player_name}`
- `{sentiment_value}` (0.0 to 1.0 float)

### RAG Context

When `g_EnableRAG = 1` and results are found, `g_RAGPromptTemplate` is formatted with:
- `{rag_info}` — concatenated text from top-N retrieved results

---

## Random Chatter Prompt Construction

**[source-backed]** — `src/mod-ollama-chat_random.cpp` `HandleRandomChatter()`

### Components

```
[SystemPrompt]
[RandomChatterPromptTemplate] with:
  {bot_name}
  {bot_level}
  {bot_class}
  {bot_race}
  {bot_gender}
  {bot_role}
  {bot_faction}
  {bot_area}
  {bot_zone}
  {bot_map}
  {bot_personality}
  {bot_personality_name}
  {environment_info}      ← selected env comment template (see below)
```

### Environment Info Selection

A random environment context type is selected based on what's available near the bot:
1. Nearby creature → selects from `g_EnvCommentCreature` templates with `{creature_name}`
2. Equipped item → `g_EnvCommentEquippedItem` with `{item_name}`
3. Bag item → `g_EnvCommentBagItem` with `{item_name}`
4. Near a vendor → `g_EnvCommentVendor` with `{vendor_name}`
5. Near a questgiver → `g_EnvCommentQuestgiver` with `{questgiver_name}`, `{quest_count}`
6. Active unfinished quest → `g_EnvCommentUnfinishedQuest` with `{quest_name}`
7. Low bag slots → `g_EnvCommentBagSlots` with `{bag_slots}`
8. Known spell → `g_EnvCommentSpell` with `{spell_name}`, `{spell_effect}`, `{spell_cost}`
9. Dungeon zone → `g_EnvCommentDungeon` with `{dungeon_name}`
10. Quest area → `g_EnvCommentQuestArea` with `{quest_area}`
11. Fallback → no environment info; prompt template sent without env context

A prompt variation from `g_RandomChatterPromptVariations` or a question from `g_RandomChatterQuestionVariations` may be appended to the environment info.

---

## Event Chatter Prompt Construction

**[source-backed]** — `src/mod-ollama-chat_events.cpp` `OllamaBotEventChatter::BuildPrompt()`

### Components

```
[SystemPrompt]
[EventChatterPromptTemplate] with:
  {bot_name}
  {bot_level}
  {bot_class}
  {bot_race}
  {bot_gender}
  {bot_role}
  {bot_faction}
  {bot_area}
  {bot_zone}
  {bot_map}
  {bot_personality}
  {bot_personality_name}
  {event_type}        ← one of the configured EventType* strings
  {event_detail}      ← e.g. creature name, item name, quest name, spell name
  {actor_name}        ← the player who triggered the event (or the bot itself)
  {sentiment_info}    ← SentimentPromptTemplate (if enabled and applicable)
```

Event detail varies by event type:
| Event | `{event_detail}` Content |
|-------|------------------------|
| Defeated | creature name |
| DefeatedPlayer | player name |
| GotItem | item name |
| Died | empty or cause |
| CompletedQuest | quest name |
| LearnedSpell | spell name |
| WonDuel | opponent name |
| LeveledUp | new level number |
| Achievement | achievement name |
| UsedObject | object name |

---

## Prompt Size Concerns

The total prompt string can become large when all optional components are enabled simultaneously:
- History (5 exchanges × 2 messages × ~100 chars) ≈ 1000 chars
- Snapshot context ≈ 500-1500 chars
- RAG context (3 results × ~500 chars) ≈ 1500 chars
- Sentiment text ≈ 100 chars
- Core prompt template ≈ 300-500 chars

**Total can exceed 4000 characters / ~1000 tokens before the user message.**

This is a known concern when `g_OllamaNumCtx` is small. The module does not currently validate that total prompt length fits within the model's context window.

---

## Design Issues with Current Prompt Architecture

| Issue | Location | Phase |
|-------|----------|-------|
| History is concatenated into a flat string rather than messages array | `GetBotHistoryPrompt()` | Phase 3B (OpenAI provider will use messages array) |
| No maximum prompt token budget validation | `GenerateBotPrompt()` | Phase 6 |
| `ExtractTextBetweenDoubleQuotes()` can clip valid content | `QueryOllamaAPI()` | Phase 3A |
| Default prompt templates not reviewed for 3.3.5a lore accuracy | conf.dist | Phase 6 |
| No explicit instruction against markdown formatting | prompt templates | Phase 6 |
| No explicit instruction against opening with player name | prompt templates | Phase 6 |

---

## Prompt Architecture After Phase 3B

When the OpenAI provider is active, the `LLMRequest` struct carries:
- `systemPrompt` — the system field / system message
- `userMessage` — the assembled chat prompt string (same as today)

Future phases (post-3B) may evolve this to:
- `history` as `vector<pair<string,string>>` for proper multi-turn conversation via messages array
- Per-turn RAG injection as separate messages
- Sentiment as a system message update rather than a prompt injection

These are not Phase 3B targets.
