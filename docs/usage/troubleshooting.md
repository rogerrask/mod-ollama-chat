# Troubleshooting

> **Scope:** Diagnosing and fixing common problems with `mod-ollama-chat`.

---

## Module Not Loading

**Symptom:** No `[mod-ollama-chat]` messages in the worldserver startup log.

**Causes and fixes:**

1. **Module not in `modules/` directory**
   - Verify the module root (containing `mod-ollama-chat.cmake`) is directly inside the AzerothCore `modules/` folder
   - Rebuild AzerothCore: `cmake --build .`

2. **Config file not found**
   - The `.conf` file must be in the AzerothCore `etc/` directory
   - Check the worldserver log for a warning about missing config file
   - Copy `conf/mod_ollama_chat.conf.dist` to `etc/mod_ollama_chat.conf`

3. **`OllamaChat.Enable = 0`**
   - Check the conf file. If `Enable` is 0, the module loads but does nothing.

---

## Bots Not Responding to Chat

**Symptom:** You type in Say/Party/Guild but bots are silent.

**Diagnostic steps:**

1. Enable debug logging:
   ```ini
   OllamaChat.DebugEnabled = 1
   ```
   Reload: `.ollama reload`. Then try chatting. If there are no `[mod-ollama-chat]` log entries, the chat hook is not firing.

2. **Check if bots are in range**
   - Default Say distance: 30 yards
   - Move closer to bots and try again

3. **Check if message is blacklisted**
   - Messages starting with `.`, `!`, `/`, etc. are ignored
   - Try a plain message like `hello there`

4. **Check Ollama connection**
   From the server machine:
   ```bash
   curl http://localhost:11434/api/generate \
     -d '{"model":"<your-model>","prompt":"test","stream":false}' \
     -H "Content-Type: application/json"
   ```
   If this fails, Ollama is not running or the URL is wrong.

5. **Check model name**
   - `OllamaChat.Model` must match exactly what `ollama list` shows
   - Common mistake: `llama3.1:8b` vs `llama3.1` (without tag)

6. **Check reply chance settings**
   - `OllamaChat.PlayerReplyChance.Say` defaults to `90`
   - Set to `100` temporarily to rule out chance RNG
   - Set `OllamaChat.MaxBotsToPick = 5` to allow more bots to reply

7. **Check combat suppression**
   - If `DisableRepliesInCombat = 1` (default) and bots or the player are in combat, no replies occur

---

## Bots Respond But with Bad Quality

**Symptom:** Bots respond, but replies are irrelevant, generic, or lore-inaccurate.

**Fixes:**

1. **Use a larger model**
   - Small models (1b, 3b) often produce generic or incoherent WoW chat
   - Try `llama3.1:8b` or `mistral:7b-instruct`

2. **Customize the system prompt**
   ```ini
   OllamaChat.SystemPrompt = You are a WoW player in the Wrath of the Lich King era (patch 3.3.5a). Reply in 1-2 short sentences. No markdown. Stay in character.
   ```

3. **Enable RAG for WoW knowledge**
   ```ini
   OllamaChat.EnableRAG = 1
   OllamaChat.RAGDataPath = rag/
   ```
   Ensure the `data/rag/` JSON files are present.

4. **Check `DebugShowFullPrompt`**
   Enable this and read the full prompt in the log. If the prompt is missing bot class/race/zone data, the template may have broken placeholders.

---

## Server Crashes or Hangs

**Symptom:** Worldserver crashes or becomes unresponsive when bots start chatting.

**Causes and fixes:**

1. **Too many concurrent LLM requests**
   - Set `OllamaChat.MaxConcurrentQueries = 4` to limit parallel threads
   - Lower the reply chances to reduce request frequency

2. **Known issue: Detached threads (KI-01)**
   - In the current codebase, LLM requests run on detached `std::thread`s
   - If the server shuts down while requests are in-flight, this can crash
   - Mitigation: wait for all bots to be quiet before shutting down
   - Fix: Phase 4 of the refactor replaces detached threads

3. **Ollama running out of memory**
   - Check Ollama's own log for OOM errors
   - Use a smaller model or increase system RAM

4. **DB write errors**
   - If `SaveBotConversationHistoryToDB()` is crashing on MySQL 5.7, this is KI-04 (CTE incompatibility)
   - Workaround: disable chat history: `OllamaChat.EnableChatHistory = 0`
   - Fix: Phase 2 of the refactor replaces the CTE

---

## Config Reload Not Working

**Symptom:** `.ollama reload` runs but behavior doesn't change.

**Fixes:**
1. Verify you have `SEC_ADMINISTRATOR` access
2. Check the worldserver log for errors after reload
3. Some settings (like `MaxConcurrentQueries`) only take full effect if threads are not already running — restart the server for these

---

## History Not Persisting

**Symptom:** Bots don't remember conversations after a server restart.

**Causes and fixes:**

1. **EnableChatHistory = 0**
   - Check conf file

2. **DB tables missing**
   - Run: `SHOW TABLES LIKE 'mod_ollama_chat%';`
   - If `mod_ollama_chat_history` is missing, apply `2025_06_14_chat_history.sql`

3. **CTE error on MySQL 5.7 (KI-04)**
   - The history save function uses a CTE that requires MySQL 8.0+ or MariaDB 10.2.1+
   - Check the worldserver error log for SQL errors from `SaveBotConversationHistoryToDB`
   - Workaround: `OllamaChat.EnableChatHistory = 0` until Phase 2 is implemented

4. **Save interval not elapsed**
   - History saves every `ConversationHistorySaveInterval` minutes (default: 10)
   - Restart before the interval? History for that session is lost.

---

## Personality Not Applying

**Symptom:** Bots don't seem to have distinct personalities.

**Fixes:**
1. Verify `OllamaChat.EnableRPPersonalities = 1`
2. Check DB: `SELECT * FROM mod_ollama_chat_personality_templates;`
   - If empty, the table exists but has no content — add personality entries
3. Check `OllamaChat.DebugShowFullPrompt = 1` — verify personality text appears in prompt
4. If using `manual_only = 1` personalities, they won't be auto-assigned — use `.ollama personality set`

---

## Sentiment Tracking Not Working

**Symptom:** `EnableSentimentTracking = 1` but sentiment doesn't seem to change.

**Fixes:**
1. Check: `SHOW TABLES LIKE 'mod_ollama_chat_sentiment';` — table must exist
2. Run `.ollama sentiment view <bot> <player>` — if it returns "not found", sentiment has never been set for this pair
3. Enable debug logging and watch for sentiment analysis LLM calls in the log
4. Remember: sentiment changes very slowly (`SentimentAdjustmentStrength = 0.1` by default)

---

## Build Errors

### `nlohmann/json not found`
The bundled `deps/nlohmann/json.hpp` file is missing. Re-clone the repository with `--recursive` or download `json.hpp` manually.

### `fmt library not found`
- Ubuntu/Debian: `sudo apt install libfmt-dev`
- Windows (vcpkg): `vcpkg install fmt`
- Ensure the AzerothCore fmt target is available if building inside AC

### `HTTPS support disabled` warning
Not an error — HTTP still works. To enable HTTPS:
- Ubuntu/Debian: `sudo apt install libssl-dev`
- Windows (vcpkg): `vcpkg install openssl`
- Rebuild AzerothCore

---

## Getting More Information

1. Enable `OllamaChat.DebugEnabled = 1` and `OllamaChat.DebugShowFullPrompt = 1`
2. Reproduce the issue
3. Collect the relevant section of the worldserver log
4. Check [current-state/known-issues.md](../current-state/known-issues.md) — your issue may already be documented
