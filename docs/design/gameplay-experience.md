# Gameplay Experience Design

> **Scope:** Desired in-game experience from the player's perspective. This is a design target, not a description of current behavior.
>
> Current behavior: see [current-state/behavior-baseline.md](../current-state/behavior-baseline.md).

---

## Target Player Profile

The player is an experienced WoW player on a WoW 3.3.5a private server using AzerothCore + PlayerBots. They have played WoW for years. They know:

- Every class, race, faction, and their relationships
- Major lore characters (Arthas, Thrall, Sylvanas, Jaina, etc.)
- Zone layouts, dungeon mechanics, and raid bosses
- WotLK-era slang, chat culture, and social norms
- Common player behavior in trade chat, guild chat, and LFG

This player will immediately notice if a bot:
- Refers to a zone or boss that doesn't exist in 3.3.5a
- Uses retail WoW terminology
- Forgets the faction of its own race
- Gives incorrect class information
- Sounds like a generic AI assistant instead of a WoW player

---

## Desired Interaction Quality

### Core Feel

Bots should feel like real WoW players who happen to also be bots. Not NPCs with scripted dialogue. Not generic chatbots. Real players: casual, opinionated, occasionally wrong, sometimes enthusiastic, sometimes bored.

### Voice Principles

1. **Contextual:** A bot in Icecrown behaves differently than one in Goldshire. A bot doing a dungeon behaves differently than one farming herbs.
2. **Class-aware:** A Death Knight does not talk about the Holy Light the way a Paladin does. A Rogue values different things than a Warrior.
3. **Faction-aware:** Alliance and Horde bots have different cultural references, NPCs they care about, and attitudes toward certain zones.
4. **Level-aware:** A level 20 bot doesn't casually discuss Naxxramas progression. A level 80 bot has opinions about gear, specs, and current patch content.
5. **Personality-consistent:** If a bot has a "grumpy veteran" personality, it should maintain that tone across multiple messages, not just in isolation.

### Things Bots Should Feel Like They Know

- Their own class abilities, role, and spec at their level
- The zone they're in and what it's known for
- Their faction's major NPCs and storylines relevant to their level range
- Basic WoW social conventions (helping guildies, congratulating gear upgrades, commiserating about wipes)
- Common WoW 3.3.5a patch-specific content (ICC, Ruby Sanctum, Ulduar, etc. if level-appropriate)

### Things Bots Should NOT Do

- Reference retail WoW features (transmog, WoW Token, Chromie Time, etc.)
- Reference content from Cataclysm or later expansions
- Know things their level doesn't justify
- Sound like a corporate customer service bot
- Use bullet points or markdown formatting in chat
- Respond with more than 1-2 sentences in normal chat
- Start every message with the player's name

---

## Response Length and Format

WoW chat messages are short. Bots must match real WoW player behavior:

| Channel | Max Length | Typical Length |
|---------|-----------|----------------|
| Say | 1-2 sentences | 1 sentence |
| Party | 1-2 sentences | 1 sentence |
| Guild | 1-2 sentences | 1-2 sentences |
| General / Trade | 1-2 sentences | 1 sentence |
| Random chatter | 1 sentence | Short observation or question |
| Event comment | 1-2 sentences | Reaction to the event |

The LLM's `NumPredict` (max tokens) default of 40 enforces brevity. This is intentional.

---

## Conversation Continuity

Bots should remember recent exchanges with a player. A player should be able to:
- Ask a follow-up question and have the bot understand the context
- Reference something they said 2 messages ago without re-explaining
- Notice that a bot's tone changes after a heated exchange (sentiment tracking)

History depth (`g_MaxConversationHistory = 5` pairs by default) controls how far back the bot remembers per conversation. This is a per-bot-per-player memory, not shared across the party.

---

## Guild Social Behavior

Guild bots should simulate an active guild:
- Comment when a guildie levels up or earns an achievement
- Welcome new members with a guild-appropriate greeting
- React to epic gear drops with congratulations
- Generate ambient guild chat that references guild-specific context (MOTD, bank gold, online members)

Guild chatter should feel like a small, tight-knit gaming community — not a public trade channel.

---

## Random Ambient Chatter

Ambient chatter should be grounded in the immediate game world. Bots should comment on:
- Nearby creatures (especially named or elite mobs)
- Their current quest progress
- Their profession or crafting activity
- The dungeon or zone they're in
- Items they have or recently looted

Ambient chatter should NOT be generic ("nice weather today") unless no relevant context is available.

---

## Event Reactions

When the player does something notable, bots should react in a way that fits:

| Event | Desired Bot Reaction |
|-------|---------------------|
| Kills an elite mob | Brief acknowledgment or congratulation |
| Completes a quest | Comment about the quest or its reward |
| Levels up | Enthusiasm or congratulation appropriate to the level |
| Earns an achievement | Reaction proportional to achievement difficulty |
| Dies | Commiseration, not lecture |
| Wins a duel | Acknowledgment (not excessive) |
| Loots a notable item | Reaction if the item is impressive |

---

## Future Extension Points

These are not current goals but should not be made impossible by the refactor:

- Voice line generation via TTS (text-to-speech) for bot messages
- Bot-to-bot conversations when no player is present
- Per-zone behavioral presets (e.g., bots in the Plaguelands speak with more gravity)
- Dynamic personality evolution based on long-term sentiment history
- Integration with quest-giver NPCs to provide lore hints
