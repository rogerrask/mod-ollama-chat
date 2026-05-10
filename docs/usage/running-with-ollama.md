# Running with Ollama

> **Scope:** How to set up and use Ollama as the LLM backend for `mod-ollama-chat`.

---

## Installing Ollama

### Linux

```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### macOS

```bash
brew install ollama
```

### Windows

Download the installer from [https://ollama.ai/download](https://ollama.ai/download).

---

## Starting Ollama

```bash
ollama serve
```

By default Ollama listens on `http://localhost:11434`. Verify it's running:

```bash
curl http://localhost:11434/api/tags
```

You should see a JSON list of installed models.

---

## Choosing a Model

The model must be installed before the server starts. Pull it once:

```bash
ollama pull llama3.2:1b
```

### Model Recommendations for WoW Bot Use

| Model | Size | Speed | Quality | Notes |
|-------|------|-------|---------|-------|
| `llama3.2:1b` | ~1.5 GB RAM | Very fast | Low | Good for testing or very low-end hardware |
| `llama3.2:3b` | ~3 GB RAM | Fast | Moderate | Reasonable quality for casual chat |
| `llama3.1:8b` | ~6 GB RAM | Moderate | Good | Recommended for quality chat |
| `mistral:7b-instruct` | ~5 GB RAM | Moderate | Good | Good instruction following |
| `phi3:mini` | ~3 GB RAM | Fast | Moderate | Microsoft model; compact |
| `qwen2.5:7b` | ~5 GB RAM | Moderate | Good | Strong instruction model |

**For a single player on private server hardware:** `llama3.1:8b` or `mistral:7b-instruct` gives the best balance of response quality and speed. The WoW player base expects conversational, contextual replies — small models (1b-3b) often produce generic or incoherent text.

**For very slow hardware:** Use `llama3.2:1b` and accept lower quality. Increase `OllamaChat.TypingSimulationBaseDelay` to hide latency.

---

## Module Configuration for Ollama

```ini
# mod_ollama_chat.conf

OllamaChat.Enable = 1

# Full URL to Ollama's native API endpoint
OllamaChat.Url = http://127.0.0.1:11434/api/generate

# Model name — must match exactly what 'ollama list' shows
OllamaChat.Model = llama3.1:8b

# Response length — 40 tokens ≈ 1-2 sentences; keep this low for chat
OllamaChat.NumPredict = 40

# Randomness — 0.8 is a good starting point for varied but coherent chat
OllamaChat.Temperature = 0.8

# Concurrent LLM requests — set to your core count / 2 as a starting point
OllamaChat.MaxConcurrentQueries = 4
```

---

## System Prompt

The `OllamaChat.SystemPrompt` is sent as Ollama's `system` field:

```ini
OllamaChat.SystemPrompt = You are a World of Warcraft player in the Wrath of the Lich King era. You speak naturally, in 1-2 short sentences. You never use markdown formatting. You are familiar with WoW 3.3.5a content only.
```

This system prompt is global — it applies to all bots. The per-bot personality and chat prompt templates add additional context on top.

---

## ThinkMode (Reasoning Models)

Some models support an explicit thinking/reasoning step before generating output. This is enabled by:

```ini
OllamaChat.ThinkModeEnableForModule = 1
```

Only use this with reasoning models (DeepSeek-R1, QwQ, etc.). Standard models either ignore `think: true` or produce broken output.

Reasoning models are significantly slower (5-30 seconds per response). For real-time WoW chat this is usually too slow.

---

## Performance Tuning

### Reducing Latency

- Use the smallest model that produces acceptable quality
- Set `OllamaChat.NumPredict = 40` (don't increase this)
- Set `OllamaChat.MaxConcurrentQueries` to limit parallel requests on slow hardware
- Disable `OllamaChat.EnableSentimentTracking` (it doubles LLM calls)
- Disable `OllamaChat.EnableRAG` if it's not adding value
- Enable `OllamaChat.EnableTypingSimulation` to mask latency with a natural-feeling delay

### Increasing Quality

- Use a larger model (7B-8B parameter range)
- Customize `OllamaChat.ChatPromptTemplate` with more specific WoW context
- Enable `OllamaChat.EnableRAG = 1` and ensure `data/rag/` files are populated
- Enable `OllamaChat.EnableRPPersonalities = 1` and define personality templates in DB

### GPU Acceleration

If Ollama detects a compatible GPU (NVIDIA, AMD, Apple Silicon), it uses it automatically. Check:

```bash
ollama run llama3.1:8b "hello"
```

If the first run is slow but subsequent runs are fast, GPU VRAM is being used effectively. If every run is slow, Ollama may be running on CPU.

---

## Remote Ollama

If Ollama runs on a different machine from the game server:

1. On the Ollama machine: start with `OLLAMA_HOST=0.0.0.0 ollama serve`
2. In the module config: `OllamaChat.Url = http://<ollama-ip>:11434/api/generate`
3. Ensure the Ollama port (11434) is accessible from the game server

**Security note:** Ollama's native API has no authentication. Do not expose it to the public internet. Use a firewall rule or VPN to restrict access to the game server's IP only.

---

## Verifying the Connection

Test the connection from the game server machine:

```bash
curl http://<ollama-host>:11434/api/generate \
  -d '{"model":"llama3.1:8b","prompt":"Say hello in WoW style.","stream":false}' \
  -H "Content-Type: application/json"
```

A working response looks like:
```json
{"model":"llama3.1:8b","created_at":"...","response":"Greetings, adventurer!","done":true}
```

If this works but in-game bots don't respond, check [troubleshooting.md](troubleshooting.md).
