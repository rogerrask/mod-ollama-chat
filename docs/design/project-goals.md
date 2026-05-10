# Project Goals

> **Scope:** Forward-looking design intent. This is NOT a description of the current codebase. See [current-state/behavior-baseline.md](../current-state/behavior-baseline.md) for what currently works.

---

## Why This Project Exists

`mod-ollama-chat` adds AI-powered chat to playerbot bots on an AzerothCore + PlayerBots private server. The bots respond to player chat, comment on in-game events, and chatter among themselves. The AI is provided by a local LLM served by Ollama.

The primary use case is a **single human player on a WoW 3.3.5a private server** who wants to experience the game with AI-driven companions and NPCs that feel like real WoW players — not generic chatbots.

---

## Guiding Principles

### 1. Preserve Working Behavior First

The module has real users. Refactoring must not break observable behavior. The [Behavior Baseline](../current-state/behavior-baseline.md) is the contract. If something works now, it must still work after the refactor.

### 2. Make the Code Understandable

The current codebase has logic scattered across large files with duplicated patterns. The goal is to split responsibilities so that any developer (or AI agent) can locate the code for a given behavior and change it without reading the entire codebase.

### 3. Make the Module Testable

No automated tests exist. The module should be structured so that unit-testable components (prompt building, config parsing, history formatting) can be tested without a live server.

### 4. OpenAI-Compatible Endpoints as a First-Class Goal

Ollama's `/api/generate` is the current protocol. The design must support OpenAI-compatible endpoints (`/v1/chat/completions`) without changing how prompts are structured. This enables:
- Using remote LLMs (OpenRouter, vLLM, LM Studio, OpenAI itself)
- Better multi-turn conversation handling via the messages array (future)
- Switching providers per server without code changes

See [openai-compatible-endpoints.md](openai-compatible-endpoints.md) for the detailed design.

### 5. WoW 3.3.5a Lore and World Fidelity

The target user is experienced with WoW and will notice incorrect information about classes, races, zones, factions, lore, and mechanics. The module's prompts and RAG data must be accurate to **Wrath of the Lich King (3.3.5a patch)**, not retail WoW.

See [wow-3.3.5a-lore-and-world-context.md](wow-3.3.5a-lore-and-world-context.md) and [gameplay-experience.md](gameplay-experience.md) for the detailed design.

### 6. No Over-Engineering

Every change must earn its complexity. Changes that don't directly serve one of the goals above should not be added.

---

## What Is NOT a Goal

- Full-featured chat platform with webhooks, APIs, or admin UIs
- Support for multiple simultaneous human players (though this should not be broken if it happens to work)
- Replacing playerbot AI behavior or combat logic
- Supporting WoW expansions other than 3.3.5a
- Replacing the playerbot system with a custom bot framework
- Implementing RAG using neural embeddings (TF cosine similarity is sufficient for WoW context)

---

## Success Criteria

A successful refactor achieves all of the following:

1. **Parity:** All behavior from the [behavior baseline](../current-state/behavior-baseline.md) continues to work
2. **Cleaner code:** No file exceeds ~500 lines; each file has a single stated responsibility
3. **No known high-severity bugs:** All KI-01, KI-02, KI-03, KI-04, KI-05 issues are resolved
4. **Two LLM providers:** Ollama and OpenAI-compatible, switchable via config
5. **Documented prompts:** Every prompt template is documented with its purpose, placeholders, and intended behavior
6. **Installation guide:** A new user can follow [usage/installation.md](../usage/installation.md) and get the module running
7. **Lore accuracy:** The default prompts and RAG data are accurate for WoW 3.3.5a

---

## Phase Summary

| Phase | Goal |
|-------|------|
| 0 | Documentation baseline (this phase) |
| 1 | Low-risk cleanup (duplicated code, dead code, raw pointers) |
| 2 | Database and SQL hardening (CTE fix, parameterized queries, indexes) |
| 3A | Handler refactor (split god file into focused files) |
| 3B | LLM provider abstraction (Ollama + OpenAI-compatible interface) |
| 4 | Thread safety (bounded thread pool, mutex scope reduction) |
| 5 | Schema and migration polish (migration files, index cleanup) |
| 6 | Prompt and lore quality pass (WoW 3.3.5a accuracy, RAG expansion) |

See [plans/refactor-roadmap.md](../plans/refactor-roadmap.md) for the full plan.
