# OpenAI-Compatible Endpoints

> **Scope:** Design for the LLM provider abstraction (Phase 3B). The current module only supports Ollama's native `/api/generate` protocol. This document defines the design for adding OpenAI-compatible endpoint support without breaking existing behavior.

---

## Why This Matters

The Ollama `/api/generate` endpoint is a flat single-string prompt protocol. OpenAI-compatible endpoints (`/v1/chat/completions`) use a structured `messages` array with roles (`system`, `user`, `assistant`). This difference matters because:

1. **Remote LLMs:** OpenRouter, vLLM, LM Studio, Groq, and many others expose OpenAI-compatible APIs, not Ollama's format
2. **Better history handling:** The messages array natively encodes conversation history with role labels, rather than concatenating it into a single prompt string
3. **Authentication:** OpenAI-compatible endpoints use Bearer token auth; Ollama has no auth
4. **Provider flexibility:** Server operators may want to switch providers without rebuilding the module

---

## Design Principles

1. **Parity first:** The Ollama provider must produce identical results to the current code before the OpenAI provider is written
2. **No prompt redesign simultaneously:** Prompt templates are not changed in Phase 3B. The OpenAI provider uses the same prompt text, just packaged differently
3. **Runtime selection:** Provider is chosen by config, not by compile flag
4. **Interface, not framework:** A simple pure virtual interface, not a plugin system

---

## Interface Design

```cpp
// src/mod-ollama-chat_llmprovider.h

struct LLMRequest {
    std::string systemPrompt;    // goes into "system" field / system message
    std::string userMessage;     // the final user turn
    // future: std::vector<std::pair<std::string, std::string>> history; // {role, content}
};

struct LLMResponse {
    std::string text;       // response text, empty on error
    bool success;           // false on network/parse error
    std::string error;      // error message for logging
};

class ILLMProvider {
public:
    virtual ~ILLMProvider() = default;
    virtual LLMResponse Complete(const LLMRequest& request) = 0;
    virtual bool IsAvailable() = 0;
    virtual void Reconfigure() = 0;
};
```

The `LLMRequest` struct is intentionally minimal in Phase 3B. History flattening (for the Ollama provider) vs. history as a messages array (for the OpenAI provider) is an implementation detail of each provider.

---

## OllamaProvider (Phase 3B)

`OllamaProvider` wraps the existing `QueryOllamaAPI()` logic with no behavioral change:

- Flattens history into a single `prompt` string (same as today)
- Uses `systemPrompt` as Ollama's `system` field
- Posts to `g_OllamaUrl` (which remains the full URL including path)
- Returns `LLMResponse` with the result or empty text on error

**This provider must produce exactly the same output as `QueryOllamaAPI()` today before any other changes are made.**

---

## OpenAICompatibleProvider (Phase 3B)

`OpenAICompatibleProvider` implements the OpenAI chat completions protocol:

```
POST /v1/chat/completions
Authorization: Bearer <token>
Content-Type: application/json

{
  "model": "<model>",
  "messages": [
    { "role": "system", "content": "<systemPrompt>" },
    { "role": "user", "content": "<userMessage>" }
  ],
  "max_tokens": <numPredict>,
  "temperature": <temperature>,
  "top_p": <topP>,
  "frequency_penalty": <repeatPenalty - 1.0>,  // approximate mapping
  "stop": [<stopSequences>]
}
```

Response parsing:
```json
{
  "choices": [
    { "message": { "content": "..." } }
  ]
}
```

The provider reads `choices[0].message.content` and returns it as `LLMResponse.text`.

---

## Config Keys (Phase 3B Additions)

| Key | Type | Default | Notes |
|-----|------|---------|-------|
| `OllamaChat.Provider` | string | `ollama` | `ollama` or `openai` |
| `OllamaChat.OpenAIBaseUrl` | string | `""` | Base URL without path (e.g. `http://localhost:8080`) |
| `OllamaChat.OpenAIApiKey` | string | `""` | Bearer token; leave empty for unauthenticated |
| `OllamaChat.OpenAIModel` | string | `""` | If empty, falls back to `OllamaChat.Model` |

The `OllamaChat.Url` key continues to work for the Ollama provider (it includes the full path). The OpenAI provider uses `OllamaChat.OpenAIBaseUrl` + `/v1/chat/completions`.

---

## Provider Selection

In `LoadOllamaChatConfig()`:

```cpp
std::string providerName = sConfigMgr->GetOption<std::string>("OllamaChat.Provider", "ollama");
if (providerName == "openai") {
    g_LLMProvider = std::make_unique<OpenAICompatibleProvider>();
} else {
    g_LLMProvider = std::make_unique<OllamaProvider>();
}
g_LLMProvider->Reconfigure();
```

`g_LLMProvider` replaces the direct `QueryOllamaAPI()` call in `QueryManager::processQuery()`.

---

## Parameter Mapping: Ollama vs. OpenAI

| Ollama Field | OpenAI Field | Notes |
|-------------|-------------|-------|
| `model` | `model` | Direct |
| `prompt` (flat string) | `messages[].content` | OllamaProvider flattens; OpenAI uses array |
| `system` | `messages[0] = {role:"system"}` | OllamaProvider uses field; OpenAI prepends to array |
| `options.num_predict` | `max_tokens` | Direct |
| `options.temperature` | `temperature` | Direct |
| `options.top_p` | `top_p` | Direct |
| `options.repeat_penalty` | `frequency_penalty` | Approximate; Ollama 1.1=none, OpenAI 0.0=none |
| `options.num_ctx` | *(not standard)* | Ignored for OpenAI provider |
| `options.seed` | `seed` | Direct where supported |
| `stop` | `stop` | Direct |
| `think` / `hidethinking` | *(not standard)* | Ignored for OpenAI provider |
| `stream: false` | `stream: false` | Direct |

---

## Security Considerations

- `OllamaChat.OpenAIApiKey` is a credential. It must not appear in logs, debug output, or server broadcast messages.
- The key must be read from the conf file only, never hardcoded.
- If the key is empty, the `Authorization` header is omitted entirely (not sent as `Bearer `).
- HTTPS should be used when sending API keys to remote endpoints. Document this requirement clearly in the usage guide.

---

## Compatibility Matrix

| Provider Setting | Ollama local | OpenRouter | vLLM | LM Studio | OpenAI |
|----------------|-------------|-----------|------|----------|--------|
| `Provider = ollama` | ✅ | ✗ | ✗ | ✗ | ✗ |
| `Provider = openai` | ✅ (Ollama compat endpoint) | ✅ | ✅ | ✅ | ✅ |

When `Provider = openai` with an Ollama-hosted model, use Ollama's OpenAI-compatible endpoint: `http://localhost:11434` (not `/api/generate`).

---

## Testing Plan for Phase 3B

1. Run `OllamaProvider::Complete()` against a live Ollama instance and compare output to the legacy `QueryOllamaAPI()` for the same input — must be identical
2. Run `OpenAICompatibleProvider::Complete()` against Ollama's OpenAI endpoint and verify non-empty response
3. Run `OpenAICompatibleProvider::Complete()` against a remote OpenAI-compatible endpoint with a test API key
4. Verify that `Reconfigure()` on provider switch (via `.ollama reload`) works without server restart
5. Verify that API key never appears in LOG_INFO output even when `g_DebugEnabled = true`
