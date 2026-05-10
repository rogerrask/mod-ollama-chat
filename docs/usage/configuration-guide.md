# Configuration Guide

> **Scope:** Plain-English explanations of all config keys grouped by feature area. For the complete technical reference (types, defaults, code variables), see [current-state/configuration.md](../current-state/configuration.md).

---

## Quick Start (Minimal Config)

These are the only settings you must change from defaults:

```ini
OllamaChat.Enable = 1
OllamaChat.Url = http://127.0.0.1:11434/api/generate
OllamaChat.Model = llama3.2:1b
```

Everything else has a default that works out of the box.

---

## Core Settings

### `OllamaChat.Enable`
Master on/off switch. Set to `0` to completely disable the module without removing it.

### `OllamaChat.DebugEnabled` / `OllamaChat.DebugShowFullPrompt`
Debug logging. `DebugEnabled` adds verbose log entries. `DebugShowFullPrompt` additionally logs the full prompt sent to the LLM. Leave both off in production — full prompts can be very long.

---

## LLM Connection Settings

### `OllamaChat.Url`
Full URL to the LLM endpoint, including path. Default: `http://localhost:11434/api/generate`.

For Ollama, this is always the `/api/generate` path. For OpenAI-compatible providers (added in Phase 3B), use the `OpenAIBaseUrl` key instead.

### `OllamaChat.Model`
The model name as known to Ollama. Must match exactly what `ollama list` shows.

Examples:
- `llama3.2:1b` — very fast, 1 billion parameters
- `llama3.1:8b` — good quality, 8 billion parameters
- `mistral:7b-instruct` — good for instruction following
- `phi3:mini` — Microsoft's small model, fast

**Recommendation for WoW bot use:** A 7B-8B parameter instruct model gives the best balance of speed and response quality. Smaller models are faster but may produce less believable responses. Larger models may be too slow for real-time chat.

### `OllamaChat.NumPredict`
Maximum tokens to generate per response. Default: `40`. This enforces short responses. WoW chat messages are 1-2 sentences. Do not increase this substantially or bots will write paragraphs.

### `OllamaChat.Temperature`
Randomness in responses. Default: `0.8`. Higher = more varied, lower = more predictable. Values above 1.0 can produce incoherent text.

### `OllamaChat.MaxConcurrentQueries`
Maximum parallel LLM requests. Default: `0` (unlimited). Set to a number based on your hardware. On an 8-core machine with a small model, `4` is a reasonable limit.

---

## Chat Reply Behavior

### Reply Chances

Four channel types each have two chance settings:
- `PlayerReplyChance.*` — chance a bot replies to a **real player's** message
- `BotReplyChance.*` — chance a bot replies to **another bot's** message

Channels: `Say`, `Channel`, `Party`, `Guild`

Default values are set higher for Say (90% player reply chance) and lower for bots replying to bots (10% Say). Adjust to taste. Setting bot-to-bot chances too high creates chat flooding.

### `OllamaChat.MaxBotsToPick`
Maximum bots that reply to a single message. Default: `2`. Prevents 10 bots all answering "hi".

### `OllamaChat.SayDistance` / `OllamaChat.YellDistance`
Distance in yards within which bots can hear Say / Yell messages. Defaults: 30 / 100.

### `OllamaChat.DisableRepliesInCombat`
Default: `1` (on). Bots won't reply while fighting. Recommended to leave on.

### `OllamaChat.EnableWhisperReplies`
Default: `0` (off). Enables bots to reply to whispers. Use with care — a player whispering any bot will get a reply.

### `OllamaChat.BlacklistCommands`
Comma-separated list of message prefixes that prevent bot replies. The module already has a large default list of common command prefixes (`.`, `!`, `/`, etc.). Add any mod-specific commands here.

---

## Random Ambient Chatter

### `OllamaChat.EnableRandomChatter`
Default: `1`. Bots periodically say something unprompted based on their environment.

### `OllamaChat.MinRandomInterval` / `OllamaChat.MaxRandomInterval`
Seconds between random chatter per bot. Defaults: 45 / 180. Each bot picks a random interval in this range.

### `OllamaChat.RandomChatterBotCommentChance`
Default: `5%`. Chance any individual bot chats on a given tick. Keeps traffic low even with many bots.

### Environment Comment Templates
These pipe-separated lists (`|`) provide context for random chatter prompts. Each template uses `{}` placeholders. Bots pick a random template from the list matching the current context type.

Example:
```ini
OllamaChat.EnvCommentCreature = I see {creature_name} nearby.|That {creature_name} looks dangerous.|Watch out for that {creature_name}.
```

---

## Event Chatter

### `OllamaChat.EnableEventChatter`
Default: `1`. Bots comment on game events (kills, level ups, achievements, etc.).

### Event Type Strings
Each event has a string template and a chance (0-100%). The string appears in the prompt as `{event_type}`. For example, `EventTypeDefeated = defeated` with `EventTypeDefeated_Chance = 1` means there's a 1% chance a bot comments when another bot kills a mob.

Higher-impact events have higher default chances: WonDuel (85%), LeveledUp (75%), Achievement (75%), GotItem (65%).

---

## Conversation History

### `OllamaChat.EnableChatHistory`
Default: `1`. Bots remember recent exchanges with each player.

### `OllamaChat.MaxConversationHistory`
Default: `5`. Number of exchanges (message + reply pairs) remembered per bot-player pair. Higher values = better context but larger prompts.

### `OllamaChat.ConversationHistorySaveInterval`
Default: `10` minutes. How often history is flushed to the database. On server restart, bots reload this history.

---

## RP Personalities

### `OllamaChat.EnableRPPersonalities`
Default: `0`. When enabled, each bot is assigned a personality archetype that modifies the prompt.

Personalities are defined in the `mod_ollama_chat_personality_templates` database table. Use `.ollama personality list` to see available personalities.

Personalities with `manual_only = 1` are never assigned randomly — they can only be set via `.ollama personality set`.

---

## Sentiment Tracking

### `OllamaChat.EnableSentimentTracking`
Default: `0`. When enabled, bots track their relationship with each player and adjust tone accordingly.

**Performance warning:** Sentiment tracking makes an additional LLM call per message to analyze sentiment. This doubles the LLM load per chat exchange. Only enable on hardware that can handle the additional load.

### `OllamaChat.SentimentDefaultValue`
Default: `0.5` (neutral). New bot-player relationships start here.

---

## RAG (Retrieval-Augmented Generation)

### `OllamaChat.EnableRAG`
Default: `0`. When enabled, bots retrieve relevant WoW knowledge from JSON files in `data/rag/` and inject it into the prompt.

### `OllamaChat.RAGDataPath`
Default: `rag/`. Path to the JSON data files, relative to the server's working directory. The `data/rag/` directory contains 10 JSON files covering WoW 3.3.5a knowledge.

### `OllamaChat.RAGMaxRetrievedItems`
Default: `3`. Maximum number of knowledge items to inject into each prompt.

### `OllamaChat.RAGSimilarityThreshold`
Default: `0.3`. Minimum cosine similarity score for a knowledge item to be included. Higher = more selective.

---

## Think Mode

### `OllamaChat.ThinkModeEnableForModule`
Default: `0`. Sends `think: true` and `hidethinking: true` to Ollama for reasoning models (DeepSeek-R1, QwQ, etc.). Only enable if using a reasoning model — standard models ignore this field.

---

## Typing Simulation

### `OllamaChat.EnableTypingSimulation`
Default: `0`. Adds a delay before the bot sends its reply, proportional to message length. Simulates human typing speed.

---

## Guild Settings

Guild chatter is separate from proximity chatter:
- `EnableGuildRandomAmbientChatter` — bots post random guild chat
- `EnableGuildEventChatter` — bots react to guild events in guild chat
- `GuildRandomChatterChance` (10%) — per-bot chance on each ambient chatter tick
- `GuildChatterBotCommentChance` (25%) — per-bot chance on guild events

Guild env comment templates use the same pipe-separated format as regular env comments, with guild-specific placeholders (`{member_name}`, `{guild_rank}`, `{bank_gold}`, etc.).

---

## Admin Commands

All commands require `SEC_ADMINISTRATOR` access:

| Command | Effect |
|---------|--------|
| `.ollama reload` | Reload config without server restart |
| `.ollama personality get <bot>` | Show bot's current personality |
| `.ollama personality set <bot> <key>` | Set bot's personality |
| `.ollama personality list` | List all personality keys |
| `.ollama sentiment view <bot> <player>` | Show sentiment score |
| `.ollama sentiment set <bot> <player> <value>` | Set sentiment (0.0-1.0) |
| `.ollama sentiment reset <bot> <player>` | Reset to default |
