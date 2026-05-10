# Testing Plan

> **Scope:** How to verify the module works correctly at each phase. The module has no automated test suite today. This plan describes what to test, how, and what a passing result looks like.

---

## Testing Philosophy

The module is an AzerothCore plugin that runs inside a live game server. True unit testing requires decoupling from the game engine. That decoupling is a goal of the refactor, not a starting condition. Until it is achieved, the primary test method is **manual in-game testing against a known checklist**.

Test levels:
1. **Compile test** — module builds without errors or warnings
2. **Load test** — server starts, module logs no errors, `.ollama reload` succeeds
3. **Behavioral smoke test** — quick manual verification of all 12 baseline behaviors
4. **Regression test** — full baseline checklist run after any change
5. **Feature test** — specific tests for new features added per phase

---

## Compile Test

Run after every code change:

```bash
# From AzerothCore build directory
cmake --build . --target mod-ollama-chat 2>&1 | grep -E "error:|warning:"
```

**Pass criteria:** Zero errors, zero new warnings.

---

## Load Test

1. Start the AzerothCore worldserver with the module
2. Watch the log for `[mod-ollama-chat]` entries — no ERROR or FATAL level
3. Log in as GM
4. Run `.ollama reload` in-game
5. Watch the log — no ERROR entries after reload

**Pass criteria:** Server starts; `.ollama reload` logs "Config loaded" (or equivalent) with no errors.

---

## Behavioral Smoke Test

Minimum test to confirm no catastrophic regressions. Run after every phase.

**Setup:**
- AzerothCore + PlayerBots running
- At least 2 bots near the player character
- `OllamaChat.Enable = 1`
- Ollama running with a working model
- All chat features enabled

| # | Test Action | Expected Result |
|---|------------|----------------|
| 1 | `/say Hello` | At least one bot replies in Say channel within ~10 seconds |
| 2 | `/p Hello party` (in group) | At least one grouped bot replies in Party |
| 3 | Whisper a bot | Bot replies in whisper (if `EnableWhisperReplies = 1`) |
| 4 | `/say .duel` (blacklisted) | No bot replies |
| 5 | Wait 3 minutes near bots | At least one random ambient message from a bot |
| 6 | Kill a mob near bots | At least one event chatter message within ~15 seconds |
| 7 | Level up | At least one bot congratulates in Say or Guild |
| 8 | `.ollama reload` | Server does not crash; bots continue replying after reload |
| 9 | `.ollama personality list` | List of personalities printed in console |
| 10 | `.ollama sentiment view <botname> <playername>` | Sentiment score printed |
| 11 | Disable Ollama, `/say Hello` | No bot replies; no server error |
| 12 | Re-enable Ollama, `/say Hello` | Bots resume replying |

---

## Regression Test Checklist

Extended version of smoke test to run before merging any phase:

### Chat Reply Path
- [ ] Say reply at close range
- [ ] Say reply blocked at max range (> SayDistance)
- [ ] Yell reply at close range
- [ ] No Yell reply at max yell range (> YellDistance)
- [ ] Party reply to all group members
- [ ] Guild reply to all online guild members
- [ ] Whisper reply (when enabled)
- [ ] No reply to blacklisted command prefix (`.`, `!`, `#`)
- [ ] No reply when module disabled (`OllamaChat.Enable = 0`)
- [ ] No reply when channel disabled (`DisableForSayYell = 1`)
- [ ] MaxBotsToPick enforced (set to 1, confirm only 1 bot replies)
- [ ] Bot in combat does not reply (DisableRepliesInCombat = 1)

### Random Chatter
- [ ] Random chatter fires within 3 minutes
- [ ] Random chatter respects MinRandomInterval (no spam)
- [ ] Random chatter stops when all players leave area

### Event Chatter
- [ ] Kill event
- [ ] Loot event (with notable item)
- [ ] Death event
- [ ] Quest complete event
- [ ] Level up event
- [ ] Achievement event
- [ ] Duel events (request, start, win)
- [ ] Game object use event

### Database
- [ ] Conversation history saves to DB after ConversationHistorySaveInterval
- [ ] History is bounded: more than MaxConversationHistory rows are trimmed
- [ ] Bot personality persists across server restart
- [ ] Sentiment score persists across server restart

### Admin Commands
- [ ] `.ollama reload` — no crash, bots resume
- [ ] `.ollama personality get <bot>` — returns result
- [ ] `.ollama personality set <bot> <key>` — applies immediately
- [ ] `.ollama personality list` — lists all keys
- [ ] `.ollama sentiment view <bot> <player>` — returns score
- [ ] `.ollama sentiment set <bot> <player> <value>` — applies immediately
- [ ] `.ollama sentiment reset <bot> <player>` — resets to default

---

## Phase-Specific Tests

### Phase 1
- [ ] `grep -r "static.*SplitString" src/` returns 0 results outside utilities.h
- [ ] `g_RAGSystem` is a `unique_ptr`; reload does not leak memory (verify with ASAN)
- [ ] Personality DB insert logged on failure

### Phase 2
- [ ] Run `SaveBotConversationHistoryToDB()` on MySQL 5.7 — no error
- [ ] Run on MariaDB 10.1 — no error
- [ ] Fill history table beyond MaxConversationHistory — confirm trimming works on all DB versions
- [ ] Attempt SQL injection via crafted player message — confirm no query modification

### Phase 3A
- [ ] No file in `src/` exceeds 500 lines
- [ ] `handler.cpp` no longer contains `GenerateBotPrompt()`, `GetBotHistoryPrompt()`, `ChatHandler_GetBotSpellInfo()`, `ChatHandler_GetGroupStatus()`, `FormatPlayerClass()`, `FormatPlayerRace()`, `IsBotEligibleForChatChannelLocal()`
- [ ] All 12 baseline behaviors still pass

### Phase 3B
- [ ] `Provider = ollama` gives identical output to pre-3B for same input (compare text manually)
- [ ] `Provider = openai` with Ollama's OpenAI endpoint (`http://localhost:11434`) returns valid reply
- [ ] API key not present in any log line (grep the worldserver log after a test session)
- [ ] `.ollama reload` with provider change applies new provider without restart

### Phase 4
- [ ] Run TSAN on a build with concurrent `/say` spam — no data race reported
- [ ] Kill worldserver while 5+ LLM queries are in-flight — no crash, no zombie threads
- [ ] History save does not hold mutex during DB write (review code + TSAN)

### Phase 6
- [ ] Parsed bot responses contain no markdown formatting (`**`, `##`, `-`, `*`)
- [ ] Parsed bot responses do not open with the player's name
- [ ] No bot response references a retail WoW feature or post-WotLK expansion
- [ ] RAG retrieval returns relevant results for at least 5 sample WoW queries

---

## Tools

| Tool | Purpose |
|------|---------|
| AzerothCore worldserver debug build | Runtime testing |
| ASAN (`-fsanitize=address`) | Memory leak detection |
| TSAN (`-fsanitize=thread`) | Data race detection |
| `sqlmap` (optional) | SQL injection surface check |
| `grep` / `ripgrep` | Quick code pattern verification |
| Manual in-game testing | Primary test method for all phases |
