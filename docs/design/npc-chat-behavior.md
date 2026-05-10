# NPC Chat Behavior Design

> **Scope:** Design guidelines for how individual bots should behave in chat, covering reply logic, channel routing, bot-to-bot interaction, and filtering rules.
>
> Current implementation: see [current-state/runtime-flow.md](../current-state/runtime-flow.md).

---

## Reply Decision Tree

When a player message arrives, the following decisions are made in sequence:

```
1. Is the module enabled?                          → NO: skip
2. Is the message a blacklisted command prefix?    → YES: skip
3. Is the message source a disabled channel?       → YES: skip
4. Are bots available near the player?             → NO: skip
5. For each eligible bot (up to MaxBotsToPick):
   a. Is the bot in combat and DisableRepliesInCombat set? → YES: skip bot
   b. Roll chance for channel type                         → FAIL: skip bot
   c. Build prompt, submit to LLM asynchronously
6. Up to MaxBotsToPick bots have responded
```

---

## Who Gets to Reply

### Real Player → Bot

A bot replies to a real player's message if:
- The bot is within `g_SayDistance` for Say, or `g_YellDistance` for Yell
- The bot is in the same group for Party/Raid
- The bot is in the same guild for Guild
- The bot passes a `[0, 100)` chance roll against the per-channel `PlayerReplyChance_*` value
- The bot is not in combat (if `g_DisableRepliesInCombat` is set)
- The player message is not a blacklisted command

### Bot → Bot

A bot can react to another bot's message using `BotReplyChance_*` per channel. This allows organic bot-to-bot conversation. Bot-to-bot reply chance is intentionally lower than player-to-bot to avoid chat flooding.

### Maximum Bots Per Message

`g_MaxBotsToPick` (default 2) limits how many bots respond to a single message. Candidates are evaluated in order until the limit is reached or no more eligible bots exist.

---

## Channel Routing

The bot sends its reply on the same channel type as the incoming message:

| Incoming Channel | Bot Reply Channel |
|-----------------|------------------|
| SAY | SAY |
| YELL | SAY (bots don't yell back) |
| PARTY | PARTY |
| RAID | PARTY (or SAY if not in a raid subgroup — [inferred]) |
| GUILD | GUILD |
| OFFICER | GUILD ([inferred] — officer access not verified) |
| CHANNEL | Depends on configured channel exclusion |
| WHISPER | WHISPER (if `g_EnableWhisperReplies = 1`) |

**Note:** Channel routing is inferred from the `ChatChannelSourceLocal` enum values and the `ProcessChat()` function. Exact routing code should be reviewed during Phase 3A refactoring.

---

## Combat Behavior

When `g_DisableRepliesInCombat = 1` (default):
- Bots in combat ignore incoming chat
- Random chatter is also suppressed for bots in combat (verified at `HandleRandomChatter()`)
- Event chatter from combat events (kills, deaths, loots) still fires because these events originate from the event hook, not from chat

---

## Bot Self-Comment (Event Chatter)

A bot can comment on its own events (e.g., commenting on an item it just looted). The `g_EventChatterBotSelfCommentChance` (default 5%) controls this separately from the chance for other bots to comment on a different player's events.

---

## Filtering Rules

### Blacklist Prefix Matching

`g_BlacklistCommands` is populated at startup with:
1. A hardcoded set of common command prefixes (`.`, `!`, `#`, `@`, `/`, etc.)
2. Any additional prefixes from `OllamaChat.BlacklistCommands` conf key

If a message starts with any blacklisted prefix, no bots respond. This prevents bots from reacting to GM commands, script calls, or mod-specific syntax.

### Channel Disable Switches

Four global disable switches:
- `g_DisableForCustomChannels` — disables all non-default channels
- `g_DisableForSayYell` — disables Say and Yell
- `g_DisableForGuild` — disables Guild chat
- `g_DisableForParty` — disables Party and Raid

These are independent and can be combined.

---

## Response Content Rules (Design Intent)

These are guidelines for prompt design (Phase 6), not current code enforcement:

1. **Max 2 sentences in reply** — enforced loosely by `NumPredict = 40` tokens
2. **No markdown formatting** — must be stated explicitly in the prompt
3. **No opening with the player's name** — prompt must instruct against this
4. **Stay in character for the bot's class and faction** — prompt context includes class/race/faction
5. **Do not break the fourth wall** — bots should not reference being AI or bots
6. **Do not invent lore** — if the bot doesn't know something, it should say so in character

---

## Guild Chat vs. Proximity Chat

Guild chat operates under different rules than proximity chat:

- Proximity chat requires distance checks (`g_SayDistance`, `g_YellDistance`)
- Guild chat requires both players and bots to be in the same guild
- Guild event chatter (`g_EnableGuildEventChatter`) fires for game events (level up, gear, joins) on guild chat

Guild ambient chatter (`g_EnableGuildRandomAmbientChatter`) fires separately from proximity ambient chatter, on a separate chance (`g_GuildRandomChatterChance`).

---

## Sentiment Influence on Behavior

When `g_EnableSentimentTracking = 1`:
- Each bot maintains a per-player sentiment score (0.0 hostile → 1.0 friendly)
- The sentiment score is injected into the prompt via `g_SentimentPromptTemplate`
- The LLM is expected to adjust tone accordingly
- Sentiment changes after each exchange via `UpdateBotPlayerSentiment()`

This is a soft influence — the LLM is told the sentiment but not forced to exhibit specific behavior.

---

## Bot-to-Bot Conversation (Forwarding)

When a bot's reply is sent on a channel that other bots can hear, those bots may also reply (at reduced `BotReplyChance_*` odds). This creates the appearance of a conversation thread. The system does NOT maintain a separate "bot conversation" state — each message goes through the same `ProcessChat()` pipeline regardless of whether the sender is human or bot.

---

## Known Behavioral Gaps (Design Targets for Phase 3A+)

| Gap | Desired Behavior | Phase |
|-----|-----------------|-------|
| Duplicate channel validation logic | `IsBotEligibleForChatChannelLocal()` and `ProcessBotChatMessage()` implement similar logic independently | Phase 3A |
| No priority for contextually relevant bots | Any eligible bot can reply; should prefer bots with more relevant context (e.g., same quest) | Phase 6 |
| No cooldown between bot replies to same player | A bot could reply to every message — only `MaxBotsToPick` limits this per message, not per conversation | Phase 3A or later |
| No faction-aware channel routing for custom channels | Custom channels don't check faction | unknown |
