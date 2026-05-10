# Configuration Reference

> **Scope:** Complete config key inventory. Source: `conf/mod_ollama_chat.conf.dist` and `src/mod-ollama-chat_config.cpp` `LoadOllamaChatConfig()`. All entries are **[source-backed]**.
>
> For plain-English explanations aimed at operators, see [usage/configuration-guide.md](../usage/configuration-guide.md).

---

## Core Module Toggles

| Config Key | Type | Default | Code Variable | Notes |
|-----------|------|---------|--------------|-------|
| `OllamaChat.Enable` | bool | `1` | `g_Enable` | Master on/off switch |
| `OllamaChat.DebugEnabled` | bool | `0` | `g_DebugEnabled` | Enables verbose logging |
| `OllamaChat.DebugShowFullPrompt` | bool | `0` | `g_DebugShowFullPrompt` | Logs full prompt sent to LLM (requires DebugEnabled) |

---

## LLM Connection and Inference

| Config Key | Type | Default | Code Variable | Notes |
|-----------|------|---------|--------------|-------|
| `OllamaChat.Url` | string | `http://localhost:11434/api/generate` | `g_OllamaUrl` | Full URL including path |
| `OllamaChat.Model` | string | `llama3.2:1b` | `g_OllamaModel` | Ollama model identifier |
| `OllamaChat.NumPredict` | uint32 | `40` | `g_OllamaNumPredict` | Max tokens to generate; 0 = unlimited |
| `OllamaChat.Temperature` | float | `0.8` | `g_OllamaTemperature` | Randomness; 0.0=deterministic, 1.0=chaotic |
| `OllamaChat.TopP` | float | `0.95` | `g_OllamaTopP` | Nucleus sampling threshold |
| `OllamaChat.RepeatPenalty` | float | `1.1` | `g_OllamaRepeatPenalty` | Repetition penalty; 1.0=none |
| `OllamaChat.NumCtx` | uint32 | `0` | `g_OllamaNumCtx` | Context window tokens; 0=model default |
| `OllamaChat.NumThreads` | uint32 | `0` | `g_OllamaNumThreads` | CPU threads; 0=model default |
| `OllamaChat.Stop` | string | `""` | `g_OllamaStop` | Comma-separated stop sequences |
| `OllamaChat.SystemPrompt` | string | `""` | `g_OllamaSystemPrompt` | Global system prompt sent to Ollama `system` field |
| `OllamaChat.Seed` | string | `""` | `g_OllamaSeed` | Random seed for determinism; parsed as int |
| `OllamaChat.MaxConcurrentQueries` | uint32 | `0` | `g_MaxConcurrentQueries` | Max parallel LLM calls; 0=unlimited |
| `OllamaChat.ThinkModeEnableForModule` | bool | `0` | `g_ThinkModeEnableForModule` | Enables `think:true` for reasoning models |

---

## General Response Logic

| Config Key | Type | Default | Code Variable | Notes |
|-----------|------|---------|--------------|-------|
| `OllamaChat.DisableRepliesInCombat` | bool | `1` | `g_DisableRepliesInCombat` | Silences bots while in combat |
| `OllamaChat.EnableWhisperReplies` | bool | `0` | `g_EnableWhisperReplies` | Enable bot replies to whispers |
| `OllamaChat.MaxBotsToPick` | uint32 | `2` | `g_MaxBotsToPick` | Max bots that respond to a single message |
| `OllamaChat.BlacklistCommands` | string | *(long list)* | `g_BlacklistCommands` | Comma-separated prefixes that suppress bot replies |

### Per-Channel Reply Chances

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.PlayerReplyChance.Say` | uint32 | `90` | `g_PlayerReplyChance_Say` |
| `OllamaChat.BotReplyChance.Say` | uint32 | `10` | `g_BotReplyChance_Say` |
| `OllamaChat.PlayerReplyChance.Channel` | uint32 | `60` | `g_PlayerReplyChance_Channel` |
| `OllamaChat.BotReplyChance.Channel` | uint32 | `3` | `g_BotReplyChance_Channel` |
| `OllamaChat.PlayerReplyChance.Party` | uint32 | `90` | `g_PlayerReplyChance_Party` |
| `OllamaChat.BotReplyChance.Party` | uint32 | `25` | `g_BotReplyChance_Party` |
| `OllamaChat.PlayerReplyChance.Guild` | uint32 | `70` | `g_PlayerReplyChance_Guild` |
| `OllamaChat.BotReplyChance.Guild` | uint32 | `5` | `g_BotReplyChance_Guild` |

---

## Distance Settings

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.SayDistance` | float | `30.0` | `g_SayDistance` |
| `OllamaChat.YellDistance` | float | `100.0` | `g_YellDistance` |
| `OllamaChat.RandomChatterRealPlayerDistance` | float | `200.0` | `g_RandomChatterRealPlayerDistance` |
| `OllamaChat.EventChatterRealPlayerDistance` | float | `40.0` | `g_EventChatterRealPlayerDistance` |

---

## Channel Disable Switches

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.DisableForCustomChannels` | bool | `0` | `g_DisableForCustomChannels` |
| `OllamaChat.DisableForSayYell` | bool | `0` | `g_DisableForSayYell` |
| `OllamaChat.DisableForGuild` | bool | `0` | `g_DisableForGuild` |
| `OllamaChat.DisableForParty` | bool | `0` | `g_DisableForParty` |

---

## Random Chatter System

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.EnableRandomChatter` | bool | `1` | `g_EnableRandomChatter` |
| `OllamaChat.MinRandomInterval` | uint32 | `45` | `g_MinRandomInterval` (seconds) |
| `OllamaChat.MaxRandomInterval` | uint32 | `180` | `g_MaxRandomInterval` (seconds) |
| `OllamaChat.RandomChatterBotCommentChance` | uint32 | `5` | `g_RandomChatterBotCommentChance` (%) |
| `OllamaChat.RandomChatterMaxBotsPerPlayer` | uint32 | `2` | `g_RandomChatterMaxBotsPerPlayer` |
| `OllamaChat.RandomChatterPromptTemplate` | string | *(WoW template)* | `g_RandomChatterPromptTemplate` |
| `OllamaChat.RandomChatterPromptVariations` | string | *(pipe-separated list)* | `g_RandomChatterPromptVariations` |
| `OllamaChat.RandomChatterQuestionVariations` | string | *(pipe-separated list)* | `g_RandomChatterQuestionVariations` |

**Placeholders for `RandomChatterPromptTemplate`:** `{bot_name}`, `{bot_level}`, `{bot_class}`, `{bot_race}`, `{bot_gender}`, `{bot_role}`, `{bot_faction}`, `{bot_area}`, `{bot_zone}`, `{bot_map}`, `{bot_personality}`, `{bot_personality_name}`, `{environment_info}`

---

## Event Chatter System

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.EnableEventChatter` | bool | `1` | `g_EnableEventChatter` |
| `OllamaChat.EventChatterBotCommentChance` | uint32 | `25` | `g_EventChatterBotCommentChance` (%) |
| `OllamaChat.EventChatterBotSelfCommentChance` | uint32 | `5` | `g_EventChatterBotSelfCommentChance` (%) |
| `OllamaChat.EventChatterMaxBotsPerPlayer` | uint32 | `2` | `g_EventChatterMaxBotsPerPlayer` |
| `OllamaChat.EventChatterPromptTemplate` | string | *(WoW template)* | `g_EventChatterPromptTemplate` |
| `OllamaChat.EventCooldownTime` | uint32 | `10` | `g_EventCooldownTime` (seconds) |

**Placeholders for `EventChatterPromptTemplate`:** `{bot_name}`, `{bot_level}`, `{bot_class}`, `{bot_race}`, `{bot_gender}`, `{bot_role}`, `{bot_faction}`, `{bot_area}`, `{bot_zone}`, `{bot_map}`, `{bot_personality}`, `{bot_personality_name}`, `{event_type}`, `{event_detail}`, `{actor_name}`, `{sentiment_info}`

### Event Type Strings and Chances

| Config Key | Default String | Chance Key | Default Chance |
|-----------|---------------|-----------|----------------|
| `OllamaChat.EventTypeDefeated` | `defeated` | `EventTypeDefeated_Chance` | `1` |
| `OllamaChat.EventTypeDefeatedPlayer` | `defeated player` | `EventTypeDefeatedPlayer_Chance` | `10` |
| `OllamaChat.EventTypePetDefeated` | `pet defeated` | `EventTypePetDefeated_Chance` | `2` |
| `OllamaChat.EventTypeGotItem` | `got item` | `EventTypeGotItem_Chance` | `65` |
| `OllamaChat.EventTypeDied` | `died` | `EventTypeDied_Chance` | `18` |
| `OllamaChat.EventTypeCompletedQuest` | `completed quest` | `EventTypeCompletedQuest_Chance` | `35` |
| `OllamaChat.EventTypeLearnedSpell` | `learned spell` | `EventTypeLearnedSpell_Chance` | `2` |
| `OllamaChat.EventTypeRequestedDuel` | `requested to duel` | `EventTypeRequestedDuel_Chance` | `28` |
| `OllamaChat.EventTypeStartedDueling` | `started dueling` | `EventTypeStartedDueling_Chance` | `10` |
| `OllamaChat.EventTypeWonDuel` | `won duel against` | `EventTypeWonDuel_Chance` | `85` |
| `OllamaChat.EventTypeLeveledUp` | `leveled up` | `EventTypeLeveledUp_Chance` | `75` |
| `OllamaChat.EventTypeAchievement` | `earned achievement` | `EventTypeAchievement_Chance` | `75` |
| `OllamaChat.EventTypeUsedObject` | `used object` | `EventTypeUsedObject_Chance` | `10` |

---

## Guild Chatter System

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.EnableGuildEventChatter` | bool | `1` | `g_EnableGuildEventChatter` |
| `OllamaChat.EnableGuildRandomAmbientChatter` | bool | `1` | `g_EnableGuildRandomAmbientChatter` |
| `OllamaChat.GuildRandomChatterChance` | uint32 | `10` | `g_GuildRandomChatterChance` (%) |
| `OllamaChat.GuildChatterBotCommentChance` | uint32 | `25` | `g_GuildChatterBotCommentChance` (%) |
| `OllamaChat.GuildChatterMaxBotsPerEvent` | uint32 | `2` | `g_GuildChatterMaxBotsPerEvent` |

### Guild Event Type Strings and Chances

| Config Key | Default String | Chance Key | Default Chance |
|-----------|---------------|-----------|----------------|
| `OllamaChat.GuildEventTypeEpicGear` | `guild member got epic gear` | `GuildEventTypeEpicGear_Chance` | `95` |
| `OllamaChat.GuildEventTypeRareGear` | `guild member got rare gear` | `GuildEventTypeRareGear_Chance` | `65` |
| `OllamaChat.GuildEventTypeGuildJoin` | `member joined guild` | `GuildEventTypeGuildJoin_Chance` | `12` |
| `OllamaChat.GuildEventTypeGuildLogin` | *(see conf.dist)* | `GuildEventTypeGuildLogin_Chance` | *(see conf.dist)* |
| `OllamaChat.GuildEventTypeGuildLeave` | *(see conf.dist)* | `GuildEventTypeGuildLeave_Chance` | *(see conf.dist)* |
| `OllamaChat.GuildEventTypeGuildPromotion` | *(see conf.dist)* | `GuildEventTypeGuildPromotion_Chance` | *(see conf.dist)* |
| `OllamaChat.GuildEventTypeGuildDemotion` | *(see conf.dist)* | `GuildEventTypeGuildDemotion_Chance` | *(see conf.dist)* |
| `OllamaChat.GuildEventTypeGuildAchievement` | *(see conf.dist)* | `GuildEventTypeGuildAchievement_Chance` | *(see conf.dist)* |
| `OllamaChat.GuildEventTypeLevelUp` | *(see conf.dist)* | `GuildEventTypeLevelUp_Chance` | *(see conf.dist)* |
| `OllamaChat.GuildEventTypeDungeonComplete` | *(see conf.dist)* | `GuildEventTypeDungeonComplete_Chance` | *(see conf.dist)* |

---

## Typing Simulation

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.EnableTypingSimulation` | bool | `0` | `g_EnableTypingSimulation` |
| `OllamaChat.TypingSimulationBaseDelay` | uint32 | `1000` | `g_TypingSimulationBaseDelay` (ms) |
| `OllamaChat.TypingSimulationDelayPerChar` | uint32 | `250` | `g_TypingSimulationDelayPerChar` (ms per char) |

---

## RP Personalities System

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.EnableRPPersonalities` | bool | `0` | `g_EnableRPPersonalities` |
| `OllamaChat.DefaultPersonalityPrompt` | string | `"Speak like a real WoW player..."` | `g_DefaultPersonalityPrompt` |

Personality templates are loaded from the `mod_ollama_chat_personality_templates` DB table, not from the conf file. The conf file only controls whether the system is enabled and what the default (non-personality) prompt says.

---

## Conversation History

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.EnableChatHistory` | bool | `1` | `g_EnableChatHistory` |
| `OllamaChat.MaxConversationHistory` | uint32 | `5` | `g_MaxConversationHistory` |
| `OllamaChat.ConversationHistorySaveInterval` | uint32 | `10` | `g_ConversationHistorySaveInterval` (minutes) |
| `OllamaChat.ChatHistoryHeaderTemplate` | string | *(see conf.dist)* | `g_ChatHistoryHeaderTemplate` |
| `OllamaChat.ChatHistoryLineTemplate` | string | *(see conf.dist)* | `g_ChatHistoryLineTemplate` |
| `OllamaChat.ChatHistoryFooterTemplate` | string | *(see conf.dist)* | `g_ChatHistoryFooterTemplate` |

---

## Bot Snapshot Template

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.EnableChatBotSnapshotTemplate` | bool | `0` | `g_EnableChatBotSnapshotTemplate` |
| `OllamaChat.ChatBotSnapshotTemplate` | string | *(see conf.dist)* | `g_ChatBotSnapshotTemplate` |

**Placeholders:** `{combat}`, `{group}`, `{spells}`, `{quests}`, `{los}`, `{players}`

---

## Chat Prompt Templates

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.ChatPromptTemplate` | string | *(WoW template)* | `g_ChatPromptTemplate` |
| `OllamaChat.ChatExtraInfoTemplate` | string | *(context template)* | `g_ChatExtraInfoTemplate` |

**Placeholders for `ChatPromptTemplate`:** `{bot_name}`, `{bot_level}`, `{bot_class}`, `{bot_personality}`, `{bot_personality_name}`, `{player_level}`, `{player_class}`, `{player_name}`, `{player_message}`, `{extra_info}`, `{sentiment_info}`, `{chat_history}`

**Placeholders for `ChatExtraInfoTemplate`:** `{bot_race}`, `{bot_gender}`, `{bot_role}`, `{bot_faction}`, `{bot_guild}`, `{bot_group_status}`, `{bot_gold}`, `{player_race}`, `{player_gender}`, `{player_role}`, `{player_faction}`, `{player_guild}`, `{player_group_status}`, `{player_gold}`, `{player_distance}`, `{bot_area}`, `{bot_zone}`, `{bot_map}`

---

## Sentiment Tracking

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.EnableSentimentTracking` | bool | `0` | `g_EnableSentimentTracking` |
| `OllamaChat.SentimentDefaultValue` | float | `0.5` | `g_SentimentDefaultValue` |
| `OllamaChat.SentimentAdjustmentStrength` | float | `0.05` | `g_SentimentAdjustmentStrength` |
| `OllamaChat.SentimentSaveInterval` | uint32 | `10` | `g_SentimentSaveInterval` (minutes) |
| `OllamaChat.SentimentAnalysisPrompt` | string | *(analysis prompt)* | `g_SentimentAnalysisPrompt` |
| `OllamaChat.SentimentPromptTemplate` | string | *(sentiment context)* | `g_SentimentPromptTemplate` |

**Warning:** Enabling sentiment tracking adds a synchronous LLM call per message. See [known-issues.md](known-issues.md) KI-03.

---

## RAG System

| Config Key | Type | Default | Code Variable |
|-----------|------|---------|--------------|
| `OllamaChat.EnableRAG` | bool | `0` | `g_EnableRAG` |
| `OllamaChat.RAGDataPath` | string | `rag/` | `g_RAGDataPath` |
| `OllamaChat.RAGMaxRetrievedItems` | uint32 | `3` | `g_RAGMaxRetrievedItems` |
| `OllamaChat.RAGSimilarityThreshold` | float | `0.3` | `g_RAGSimilarityThreshold` |
| `OllamaChat.RAGPromptTemplate` | string | *(see conf.dist)* | `g_RAGPromptTemplate` |

---

## Environment Comment Templates (Random Chatter Context)

All are pipe-separated (`|`) lists of template strings. Loaded into `std::vector<std::string>`.

| Config Key | Placeholders |
|-----------|-------------|
| `OllamaChat.EnvCommentCreature` | `{creature_name}` |
| `OllamaChat.EnvCommentGameObject` | `{object_name}` |
| `OllamaChat.EnvCommentEquippedItem` | `{item_name}` |
| `OllamaChat.EnvCommentBagItem` | `{item_name}` |
| `OllamaChat.EnvCommentBagItemSell` | `{item_count}`, `{item_name}` |
| `OllamaChat.EnvCommentSpell` | `{spell_name}`, `{spell_effect}`, `{spell_cost}` |
| `OllamaChat.EnvCommentQuestArea` | `{quest_area}` |
| `OllamaChat.EnvCommentVendor` | `{vendor_name}` |
| `OllamaChat.EnvCommentQuestgiver` | `{questgiver_name}`, `{quest_count}` |
| `OllamaChat.EnvCommentBagSlots` | `{bag_slots}` |
| `OllamaChat.EnvCommentDungeon` | `{dungeon_name}` |
| `OllamaChat.EnvCommentUnfinishedQuest` | `{quest_name}` |

## Guild Environment Comment Templates

| Config Key | Placeholders |
|-----------|-------------|
| `OllamaChat.GuildEnvCommentGuildMember` | `{member_name}` |
| `OllamaChat.GuildEnvCommentGuildRank` | `{guild_rank}` |
| `OllamaChat.GuildEnvCommentGuildBank` | `{bank_gold}` |
| `OllamaChat.GuildEnvCommentGuildMOTD` | `{guild_motd}` |
| `OllamaChat.GuildEnvCommentGuildInfo` | `{guild_info}` |
| `OllamaChat.GuildEnvCommentGuildOnlineMembers` | `{online_count}`, `{total_count}` |
| `OllamaChat.GuildEnvCommentGuildRaid` | *(none)* |
| `OllamaChat.GuildEnvCommentGuildEndgame` | *(none)* |
| `OllamaChat.GuildEnvCommentGuildStrategy` | *(none)* |
| `OllamaChat.GuildEnvCommentGuildGroup` | *(none)* |
| `OllamaChat.GuildEnvCommentGuildPvP` | *(none)* |
| `OllamaChat.GuildEnvCommentGuildCommunity` | *(none)* |
