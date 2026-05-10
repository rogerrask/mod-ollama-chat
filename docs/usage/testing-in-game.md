# Testing In-Game

> **Scope:** Step-by-step guide for verifying that the module works correctly after installation or after each refactor phase.

---

## Prerequisites

Before testing in-game:
- AzerothCore is running with the module loaded
- Ollama is running with a model loaded
- PlayerBots are enabled and working
- You have a GM account

---

## Test Environment Setup

### 1. Enable the Module

In `mod_ollama_chat.conf`:
```ini
OllamaChat.Enable = 1
OllamaChat.DebugEnabled = 1       # Enable debug logging during testing
OllamaChat.DebugShowFullPrompt = 1 # Show full prompts in the log
```

Debug logging is verbose. Review the worldserver log file while testing.

### 2. Spawn Test Bots

Using the PlayerBots commands in-game (varies by playerbot version):
```
.bot add <botname>    # Add a bot to follow you
```

Spawn at least 2 bots of different classes to verify class-specific behavior.

### 3. Ensure Ollama Is Responding

Before entering the game, verify from the server machine:
```bash
curl http://localhost:11434/api/generate \
  -d '{"model":"llama3.1:8b","prompt":"Hello, adventurer!","stream":false}' \
  -H "Content-Type: application/json"
```

---

## Core Chat Reply Tests

### Test 1: Basic Say Reply

1. Stand within 30 yards of at least one bot
2. Type `/say Hello, is anyone there?`
3. Wait up to 15 seconds
4. **Expected:** At least one bot replies in Say channel

**What to check in log:** Look for `[mod-ollama-chat]` entries showing bot selection, prompt construction, and LLM response.

### Test 2: Reply Chance Enforcement

1. Set `OllamaChat.PlayerReplyChance.Say = 100`
2. Set `OllamaChat.MaxBotsToPick = 1`
3. Type `/say` — exactly 1 bot should always reply
4. Reset both values

### Test 3: Distance Filtering

1. Move far away from bots (> 30 yards for Say)
2. Type `/say Hello`
3. **Expected:** No bot replies (too far)

### Test 4: Blacklist Filtering

1. Type `/say .somecommand`
2. **Expected:** No bot replies (`.` prefix is blacklisted)

### Test 5: Party Chat

1. Group with at least one bot
2. Type `/p Hello party`
3. **Expected:** Bot replies in Party channel

### Test 6: Guild Chat

1. Join a guild with at least one bot member
2. Type `/g Hello guildmates`
3. **Expected:** Bot replies in Guild channel

### Test 7: Whisper Reply (if enabled)

1. Set `OllamaChat.EnableWhisperReplies = 1`
2. Reload config: `.ollama reload`
3. Whisper a bot: `/w <botname> Hello`
4. **Expected:** Bot whispers back

---

## Random Chatter Tests

### Test 8: Ambient Chatter Fires

1. Stand near bots for 3-5 minutes
2. **Expected:** At least one bot says something unprompted

Adjust `OllamaChat.MinRandomInterval = 30` and `OllamaChat.MaxRandomInterval = 60` for faster testing, then reset.

### Test 9: Distance Boundary

1. Move beyond `RandomChatterRealPlayerDistance` (default 200 yards)
2. Wait several minutes
3. **Expected:** No random chatter (no real player nearby)

---

## Event Chatter Tests

### Test 10: Kill Event

1. Kill a mob near bots
2. **Expected:** Bot may comment (EventTypeDefeated_Chance = 1% by default — increase to 100 for testing)

### Test 11: Level Up

1. Level up your character (or use GM command)
2. **Expected:** Bots congratulate you

### Test 12: Quest Complete

1. Complete a quest
2. **Expected:** Bot may comment on the quest

### Test 13: Achievement

1. Earn an achievement
2. **Expected:** Bot may react

---

## Conversation History Tests

### Test 14: Context Retention

1. Have a multi-turn conversation:
   - `/say My name is Thorin`
   - (Wait for bot reply)
   - `/say What did I just tell you?`
2. **Expected:** Bot refers to your name or the earlier message

This tests that `g_BotConversationHistory` and `GetBotHistoryPrompt()` are working.

### Test 15: History Persistence

1. Have a conversation with a bot
2. Restart the worldserver
3. Ask the bot about the previous conversation
4. **Expected:** Bot remembers (loaded from DB)

---

## Admin Command Tests

### Test 16: Config Reload

```
.ollama reload
```
**Expected:** Server log shows config loaded; bots continue working.

### Test 17: Personality Commands

```
.ollama personality list
.ollama personality get <botname>
.ollama personality set <botname> <personality_key>
```
**Expected:** Each command returns expected output or applies the change.

### Test 18: Sentiment Commands

```
.ollama sentiment view <botname> <playername>
.ollama sentiment set <botname> <playername> 0.9
.ollama sentiment view <botname> <playername>    ← should show 0.9
.ollama sentiment reset <botname> <playername>
.ollama sentiment view <botname> <playername>    ← should show default (0.5)
```

---

## Regression Test After Code Changes

Run the full checklist from [testing-plan.md](../plans/testing-plan.md) after any source code change before committing.

Quick shortcut: the 12 baseline behaviors from [behavior-baseline.md](../current-state/behavior-baseline.md) are the minimum acceptable pass set.

---

## Reading the Log

Enable debug logging and watch the worldserver log while running tests:

```
# Look for these patterns:
[mod-ollama-chat] Processing chat from player <name>
[mod-ollama-chat] Selected bot: <botname>
[mod-ollama-chat] === FULL PROMPT ===   ← if DebugShowFullPrompt = 1
[mod-ollama-chat] LLM response: <text>
[mod-ollama-chat] ERROR: ...            ← any errors
```

If bots are not responding and there are no log entries at all, the module may not be enabled or the hook is not firing. Check:
1. `OllamaChat.Enable = 1`
2. The module appears in the server startup log
3. PlayerBots are actually bot characters (not player alts)

---

## Turning Off Debug Logging After Testing

```ini
OllamaChat.DebugEnabled = 0
OllamaChat.DebugShowFullPrompt = 0
```

Then reload: `.ollama reload`

Debug logging is chatty and may affect performance. Always disable it in production.
