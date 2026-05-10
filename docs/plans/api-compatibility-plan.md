# API Compatibility Plan

> **Scope:** Migration path from Ollama's native `/api/generate` protocol to the `ILLMProvider` interface that also supports OpenAI-compatible endpoints.

---

## Current API Contract

**[source-backed]** — `src/mod-ollama-chat_api.cpp`

The module currently calls Ollama's native HTTP API:

```
POST http://localhost:11434/api/generate
Content-Type: application/json

{
  "model": "llama3.2:1b",
  "prompt": "<flat prompt string>",
  "stream": false,
  "system": "<optional system prompt>",
  "options": {
    "num_predict": 40,
    "temperature": 0.8,
    "top_p": 0.95,
    "repeat_penalty": 1.1
  },
  "stop": ["<stop1>", "<stop2>"],
  "think": true,          // optional, ThinkMode only
  "hidethinking": true    // optional, ThinkMode only
}
```

Response (NDJSON):
```json
{"model":"...","response":"text fragment","done":false}
{"model":"...","response":"","done":true,"context":[...]}
```

The module accumulates all `"response"` field values until `"done": true`.

---

## Phase 3B: Provider Interface

Full design: [design/openai-compatible-endpoints.md](../design/openai-compatible-endpoints.md)

**New files:**
- `src/mod-ollama-chat_llmprovider.h` — interface definition
- `src/mod-ollama-chat_ollamaprovider.cpp/.h` — wraps existing `QueryOllamaAPI()` behavior
- `src/mod-ollama-chat_openaiprovider.cpp/.h` — OpenAI-compatible implementation

**New config keys:**
- `OllamaChat.Provider` — `ollama` (default) or `openai`
- `OllamaChat.OpenAIBaseUrl` — base URL (e.g., `http://localhost:8080`)
- `OllamaChat.OpenAIApiKey` — Bearer token
- `OllamaChat.OpenAIModel` — model name override

---

## OllamaProvider Implementation Contract

`OllamaProvider::Complete(request)` must produce identical results to the current `QueryOllamaAPI(prompt)` for all inputs:

| Behavior | Current Code | OllamaProvider Must Match |
|---------|-------------|--------------------------|
| Empty response on HTTP error | `return ""` | `response.text = ""; response.success = false` |
| NDJSON accumulation | Loop over lines, accumulate `"response"` | Same loop |
| ExtractTextBetweenDoubleQuotes | Applied after accumulation | Applied after accumulation (Phase 3A may remove this) |
| UTF-8 sanitization | `SanitizeUTF8()` before JSON construction | Same |
| ThinkMode fields | Sent if `g_ThinkModeEnableForModule` | Same |
| All optional model parameters | Sent only if non-default | Same |

**Test method:** For a given input prompt, `QueryOllamaAPI(prompt)` and `OllamaProvider::Complete({systemPrompt:"", userMessage:prompt})` must return the same string. Run at least 20 test inputs before declaring parity.

---

## OpenAICompatibleProvider Implementation Contract

The provider must:
1. Parse `OllamaChat.OpenAIBaseUrl` and append `/v1/chat/completions` as the path
2. Send `Authorization: Bearer <apikey>` header if key is non-empty
3. Build `messages` array: `[{role:"system", content:systemPrompt}, {role:"user", content:userMessage}]`
4. Map parameters (see [openai-compatible-endpoints.md](../design/openai-compatible-endpoints.md) parameter mapping table)
5. Parse response: `choices[0].message.content`
6. Return empty text on any HTTP or parse error

**Security requirement:** `apikey` must never appear in any log output.

---

## Endpoint Compatibility Notes

### Ollama OpenAI-Compatible Endpoint

Ollama ≥ 0.1.24 exposes an OpenAI-compatible endpoint at:
```
http://localhost:11434/v1/chat/completions
```
No API key needed. Set `OllamaChat.OpenAIBaseUrl = http://localhost:11434` and leave `OpenAIApiKey` empty.

### LM Studio

LM Studio exposes at `http://localhost:1234` by default.
```
OllamaChat.OpenAIBaseUrl = http://localhost:1234
OllamaChat.OpenAIApiKey = lm-studio   # required but ignored
```

### OpenRouter

```
OllamaChat.OpenAIBaseUrl = https://openrouter.ai/api
OllamaChat.OpenAIApiKey = <your-openrouter-key>
OllamaChat.OpenAIModel = mistralai/mistral-7b-instruct
```

**HTTPS required.** Ensure the module is built with OpenSSL support.

### vLLM

```
OllamaChat.OpenAIBaseUrl = http://<your-vllm-host>:8000
OllamaChat.OpenAIApiKey = <your-key-if-configured>
OllamaChat.OpenAIModel = <model-name-as-served>
```

### OpenAI

```
OllamaChat.OpenAIBaseUrl = https://api.openai.com
OllamaChat.OpenAIApiKey = sk-...
OllamaChat.OpenAIModel = gpt-4o-mini
```

**HTTPS required.** Not recommended for latency-sensitive use: OpenAI API responses are slower than a local Ollama model.

---

## Backward Compatibility

When `OllamaChat.Provider = ollama` (the default), the behavior is byte-for-byte identical to the current module. No operator action is required. The `OllamaChat.Url` key continues to work as before.

When upgrading from a pre-3B installation:
- No config changes are needed for Ollama users
- OpenAI provider users must add the 3 new config keys

---

## Rollout Plan

1. Phase 3B code complete
2. Developer tests with `Provider = ollama` — must pass all regression tests
3. Developer tests with `Provider = openai` targeting Ollama's OpenAI endpoint
4. Update `docs/usage/running-with-openai-compatible-api.md` with verified working examples
5. Announce new keys in changelog / README
