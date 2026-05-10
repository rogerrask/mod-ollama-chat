# Installation Guide

> **Scope:** How to install `mod-ollama-chat` on a fresh AzerothCore + PlayerBots server.

---

## Requirements

| Requirement | Version | Notes |
|------------|---------|-------|
| AzerothCore | Latest (`liyunfan1223/azerothcore-wotlk`) | Standard AC is not sufficient for PlayerBots |
| PlayerBots | Latest (`liyunfan1223/mod-playerbots`) | Required — bots must exist for the module to do anything |
| CMake | 3.14+ | Standard AC requirement |
| C++17 compiler | GCC 7+, Clang 5+, MSVC 2019+ | Standard AC requirement |
| MySQL | 5.7+ | Or MariaDB 10.1+ |
| Ollama | Latest | For running the AI model locally |
| fmtlib | 7.0+ | Usually provided by AzerothCore's deps; see note below |
| OpenSSL | 1.1+ | Optional; required for HTTPS endpoints only |

---

## Step 1: Place the Module

Clone or copy this repository into the AzerothCore `modules/` directory:

```bash
cd /path/to/azerothcore/modules/
git clone https://github.com/yourorg/mod-ollama-chat.git
```

Or as a git submodule:
```bash
git submodule add https://github.com/yourorg/mod-ollama-chat.git modules/mod-ollama-chat
```

The module root (containing `mod-ollama-chat.cmake`) must be directly inside `modules/`.

---

## Step 2: Build AzerothCore with the Module

Follow the standard AzerothCore build process. The module is automatically detected via `mod-ollama-chat.cmake`.

```bash
mkdir build && cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DSCRIPTS=static \
  -DMODULES=static
make -j$(nproc)
```

### Dependency Notes

**nlohmann/json:** Bundled at `deps/nlohmann/json.hpp`. No action required.

**fmtlib:** Used by AzerothCore itself. If the AC build already uses fmt, the module will find it automatically. If not:
- Ubuntu/Debian: `sudo apt install libfmt-dev`
- Windows (vcpkg): `vcpkg install fmt`

**cpp-httplib:** Bundled at `src/httplib.h`. No action required.

**OpenSSL (optional):** Only needed for HTTPS endpoints. If not found, a CMake warning appears but the build succeeds with HTTP-only support.
- Ubuntu/Debian: `sudo apt install libssl-dev`
- Windows (vcpkg): `vcpkg install openssl`

### Expected CMake Output

```
[mod-ollama-chat] Using bundled nlohmann/json
[mod-ollama-chat] Using AzerothCore fmt library
[mod-ollama-chat] OpenSSL found - HTTPS support enabled   ← or warning if missing
```

If you see `FATAL_ERROR`, one of the required dependencies is missing.

---

## Step 3: Configure the Module

Copy the example config and rename it:

```bash
cp /path/to/azerothcore/modules/mod-ollama-chat/conf/mod_ollama_chat.conf.dist \
   /path/to/azerothcore/env/dist/etc/mod_ollama_chat.conf
```

Edit the conf file and set at minimum:

```ini
OllamaChat.Enable = 1
OllamaChat.Url = http://127.0.0.1:11434/api/generate
OllamaChat.Model = llama3.2:1b
```

All other settings have sensible defaults. See [configuration-guide.md](configuration-guide.md) for the full reference.

---

## Step 4: Apply Database Migrations

Connect to your `acore_characters` database and run the SQL files in order:

```bash
mysql -u root -p acore_characters < data/sql/characters/base/2025_03_30_personalities.sql
mysql -u root -p acore_characters < data/sql/characters/base/2025_05_30_personalities.sql
mysql -u root -p acore_characters < data/sql/characters/base/2025_05_31_personality_template.sql
mysql -u root -p acore_characters < data/sql/characters/base/2025_06_14_chat_history.sql
mysql -u root -p acore_characters < data/sql/characters/base/2025_07_24_sentiment_tracking.sql
mysql -u root -p acore_characters < data/sql/characters/base/2025_11_01_personality_manual_only.sql
```

If any file returns an error about a table already existing, the table was created by a previous run. Check the DDL uses `CREATE TABLE IF NOT EXISTS`. See [database-schema.md](../current-state/database-schema.md) for the expected table structure.

---

## Step 5: Start Ollama

Install and start Ollama from [https://ollama.ai](https://ollama.ai):

```bash
ollama pull llama3.2:1b
ollama serve
```

Verify Ollama is running:
```bash
curl http://localhost:11434/api/generate \
  -d '{"model":"llama3.2:1b","prompt":"Hello","stream":false}'
```

You should see a JSON response with a `"response"` field.

---

## Step 6: Start the Server

Start AzerothCore. Watch the log for module messages:

```
[mod-ollama-chat] Config loaded
```

No ERROR or FATAL messages from the module should appear.

---

## Step 7: Verify In-Game

1. Log in as a GM character
2. Add some bots near your character (PlayerBots command)
3. Type `/say Hello` in chat
4. Wait up to 10 seconds — a bot should reply in Say channel

If no reply occurs, see [troubleshooting.md](troubleshooting.md).

---

## Upgrading from a Previous Version

1. Pull the latest module code
2. Rebuild AzerothCore
3. Apply any new SQL files from `data/sql/characters/updates/` in date order
4. Run `.ollama reload` in-game or restart the server

---

## Uninstalling

1. Remove the module from `modules/`
2. Rebuild AzerothCore
3. Optionally drop the module tables from `acore_characters`:
   ```sql
   DROP TABLE IF EXISTS mod_ollama_chat_history;
   DROP TABLE IF EXISTS mod_ollama_chat_sentiment;
   DROP TABLE IF EXISTS mod_ollama_chat_personality;
   DROP TABLE IF EXISTS mod_ollama_chat_personality_templates;
   ```
