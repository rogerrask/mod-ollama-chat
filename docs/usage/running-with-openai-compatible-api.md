# Running with OpenAI-Compatible APIs

> **Status: STUB** — This feature is planned for Phase 3B of the refactor. The current module only supports Ollama's native `/api/generate` endpoint. This document will be filled with working examples once Phase 3B is implemented.
>
> Design specification: [design/openai-compatible-endpoints.md](../design/openai-compatible-endpoints.md)

---

## What's Coming in Phase 3B

After Phase 3B is implemented, the module will support any LLM endpoint that implements the OpenAI chat completions API (`/v1/chat/completions`). This includes:

- Ollama's OpenAI-compatible endpoint (local, no key needed)
- LM Studio (local, no key needed)
- vLLM (self-hosted)
- OpenRouter (remote, API key required)
- OpenAI (remote, API key required)
- Any other OpenAI-compatible server

---

## Planned Configuration (After Phase 3B)

```ini
# Switch from Ollama native to OpenAI-compatible protocol
OllamaChat.Provider = openai

# Base URL of the OpenAI-compatible server (no path)
OllamaChat.OpenAIBaseUrl = http://localhost:11434

# API key — leave empty for unauthenticated local servers
OllamaChat.OpenAIApiKey =

# Model name for the OpenAI provider
OllamaChat.OpenAIModel = llama3.1:8b
```

---

## Current Workaround

If you need to use a remote OpenAI-compatible server now (before Phase 3B), you can run an Ollama-to-OpenAI proxy locally. However, this is not officially supported and may require additional configuration.

For all current deployments, use the Ollama native protocol as described in [running-with-ollama.md](running-with-ollama.md).

---

*This document will be updated with verified working examples after Phase 3B is complete.*
