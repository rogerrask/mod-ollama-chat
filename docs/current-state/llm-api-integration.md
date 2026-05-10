# LLM API Integration

> **Scope:** Integration as implemented in `src/mod-ollama-chat_api.cpp` (`QueryOllamaAPI()`) and `src/mod-ollama-chat_httpclient.cpp`. All claims are **[source-backed]** unless marked.

---

## Protocol

The module uses the **Ollama native API** (`/api/generate`), not the OpenAI-compatible API.

This is a single-turn, non-streaming completion endpoint. The full prompt (including system context, history, and user message) is assembled into one string before being sent. **[source-backed: api.cpp]**

Support for OpenAI-compatible endpoints (`/v1/chat/completions`) is a planned future addition — see [design/openai-compatible-endpoints.md](../design/openai-compatible-endpoints.md).

---

## Endpoint

| Setting | Default | Config Key | Code Variable |
|---------|---------|-----------|---------------|
| URL | `http://localhost:11434/api/generate` | `OllamaChat.Url` | `g_OllamaUrl` |
| Model | `llama3.2:1b` | `OllamaChat.Model` | `g_OllamaModel` |

The URL is fully configurable and can point to a remote Ollama instance. HTTPS is supported if OpenSSL was found at build time. **[source-backed]**

---

## HTTP Request

### Method and Headers

```
POST {g_OllamaUrl}
Content-Type: application/json
User-Agent: AzerothCore-OllamaChat/1.0
Accept: application/json
```

If the URL host contains `"ngrok"` or `"ngrok-free.app"`, the header `ngrok-skip-browser-warning: true` is also sent. **[source-backed: httpclient.cpp]**

### Request Body (JSON)

```json
{
  "model": "<g_OllamaModel>",
  "prompt": "<sanitized UTF-8 prompt string>",
  "stream": false,
  "options": {
    "num_predict": <g_OllamaNumPredict>,
    "temperature": <g_OllamaTemperature>,
    "top_p": <g_OllamaTopP>,
    "repeat_penalty": <g_OllamaRepeatPenalty>,
    "num_ctx": <g_OllamaNumCtx>,
    "num_thread": <g_OllamaNumThreads>
  },
  "stop": ["<seq1>", "<seq2>"],
  "system": "<g_OllamaSystemPrompt>",
  "think": true,
  "hidethinking": true
}
```

**Conditional fields:**
- `options.*` fields are only sent if their value differs from the default (to avoid overriding model defaults unnecessarily). **[source-backed: api.cpp]**
- `stop` array is only sent if `g_OllamaStop` is non-empty. Value is comma-split. **[source-backed]**
- `system` is only sent if `g_OllamaSystemPrompt` is non-empty. **[source-backed]**
- `think` and `hidethinking` are only sent if `g_ThinkModeEnableForModule` is true. **[source-backed]**
- The `options` object itself is omitted if no options are being set. **[source-backed]**

### Prompt Pre-processing

Before sending, the prompt string is passed through `SanitizeUTF8()` which replaces invalid UTF-8 byte sequences with spaces. **[source-backed: api.cpp, utilities.h]**

---

## HTTP Client

The HTTP client is `OllamaHttpClient` (`httpclient.cpp`), a thin wrapper around cpp-httplib.

**URL Parsing:** A regex extracts protocol, host, port, and path from `g_OllamaUrl`. Default port is 11434 for HTTP, 443 for HTTPS. **[source-backed: httpclient.cpp]**

**Timeouts:** Connection, read, and write timeouts are all set to 120 seconds. **[source-backed: httpclient.cpp constructor]**

**HTTP vs HTTPS selection:**
- If protocol is `https` and `CPPHTTPLIB_OPENSSL_SUPPORT` is defined: uses `httplib::SSLClient` with certificate verification disabled (to support self-signed certs and ngrok). **[source-backed]**
- If protocol is `https` without OpenSSL support: logs error and returns empty string. **[source-backed]**
- If protocol is `http`: uses `httplib::Client`. **[source-backed]**

**Static instance issue:** The `OllamaHttpClient` instance is declared `static` inside `QueryOllamaAPI()`. It is created once and reused for all subsequent calls. Config reload via `.ollama reload` does **not** recreate this client — URL or timeout changes require a server restart. **[source-backed — KI-06]**

---

## HTTP Response

Ollama returns NDJSON even when `stream: false`. The module reads lines and accumulates `"response"` field values: **[source-backed: api.cpp]**

```cpp
while (std::getline(ss, line)) {
    nlohmann::json jsonResponse = nlohmann::json::parse(line);
    if (jsonResponse.contains("response") && !jsonResponse["response"].empty())
        extractedResponse << jsonResponse["response"];
}
```

In practice with `stream: false`, Ollama returns a single JSON line containing the full response in `"response"`. The loop handles streaming responses as well, though streaming is explicitly disabled. **[inferred from Ollama API behavior]**

---

## Response Post-Processing

### ExtractTextBetweenDoubleQuotes

After accumulating the response text, `ExtractTextBetweenDoubleQuotes()` is called: **[source-backed: api.cpp]**

```cpp
std::string ExtractTextBetweenDoubleQuotes(const std::string& response) {
    size_t first = response.find('"');
    size_t second = response.find('"', first + 1);
    if (first != std::string::npos && second != std::string::npos)
        return response.substr(first + 1, second - first - 1);
    return response;
}
```

**Behavior:** If the response begins with a double-quoted string (e.g., `"Hello there!"`), this strips the quotes. If the response does not start with quotes, it is returned unchanged.

**Risk:** If the LLM response naturally contains quotes (e.g., `Sure, I'd say "hello" to anyone`), this function returns only `hello` and discards the rest. This is an inferred risk — actual frequency in practice is **[unknown]**. See [known-issues.md](known-issues.md) KI-13.

### ThinkMode Stripping

If `g_ThinkModeEnableForModule` is true, the `think: true` flag is sent to Ollama (for models that support reasoning modes). The module then checks the final response for `<think>` or `</think>` tags: **[source-backed: api.cpp]**

- If tags are found: logs a detailed error with remediation steps and returns `""` (empty — bot stays silent)
- This acts as a truncation guard for cases where thinking content was not fully stripped by the model

Whether `hidethinking: true` actually causes Ollama to strip think content varies by model. **[unknown — KI-16]**

---

## Error Handling

| Condition | Behavior |
|-----------|---------|
| HTTP client not available | Logs error, returns `""` |
| HTTP request returns non-200 status | Logs error with status code, returns `""` |
| Empty HTTP response body | Logs error, returns `""` |
| JSON parse failure | Logs exception message, returns `""` |
| Empty extracted response | Logs error, returns `""` |
| Unclosed `<think>` tags | Logs detailed error with fix steps, returns `""` |

When `""` is returned, the bot does not send any in-game message. **[inferred — no in-game test confirmation]**

---

## Concurrency

Calls to `QueryOllamaAPI()` happen on detached threads managed by `QueryManager`. The number of concurrent calls is bounded by `g_MaxConcurrentQueries` (0 = unlimited). Excess requests are queued in `QueryManager::taskQueue`. **[source-backed: querymanager.cpp]**

See [known-issues.md](known-issues.md) KI-01 for the detached thread lifecycle risk and [plans/refactor-roadmap.md](../plans/refactor-roadmap.md) Phase 4 for the fix plan.
