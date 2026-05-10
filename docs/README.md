# mod-ollama-chat Documentation

AzerothCore + Playerbots module that enables AI bot chat via Ollama or OpenAI-compatible LLM endpoints.

**Target environment:** single-player WoW 3.3.5a (Wrath of the Lich King) private server running [liyunfan1223/azerothcore-wotlk](https://github.com/liyunfan1223/azerothcore-wotlk) with [mod-playerbots](https://github.com/liyunfan1223/mod-playerbots).

---

## Folder Structure

| Folder | Purpose | Audience |
|--------|---------|----------|
| `current-state/` | Factual baseline — what the code does **today**, source-backed | Developers onboarding to the codebase |
| `design/` | Intent and goals — **future** behavior and architecture targets | Developers and contributors |
| `plans/` | Implementation plans — step-by-step dev tasks, not yet done | Developers taking on a phase |
| `usage/` | Operator guides — build, configure, run, troubleshoot | Server operators |

> **Claim labels used throughout `current-state/`:**
> - **[source-backed]** — claim is directly traceable to a specific file and function
> - **[inferred]** — claim is a reasonable conclusion from the code, but not directly asserted
> - **[unknown]** — claim cannot be confirmed from code review alone; in-game verification required

Design goals in `design/` are explicitly forward-looking. They do **not** describe current behavior unless the current-state docs confirm it.

---

## Quick Navigation

### Current State (what exists today)
- [repository-map.md](current-state/repository-map.md) — every file and its role
- [build-system.md](current-state/build-system.md) — CMake, dependencies, platform notes
- [runtime-flow.md](current-state/runtime-flow.md) — how chat events flow from player to bot reply
- [configuration.md](current-state/configuration.md) — complete config key reference
- [database-schema.md](current-state/database-schema.md) — all tables, columns, and usage
- [llm-api-integration.md](current-state/llm-api-integration.md) — Ollama API request/response details
- [known-issues.md](current-state/known-issues.md) — bugs and risks found in code review
- [evidence-map.md](current-state/evidence-map.md) — claim-to-source traceability index
- [behavior-baseline.md](current-state/behavior-baseline.md) — working / partial / unknown feature status

### Design Goals (future targets)
- [project-goals.md](design/project-goals.md) — core mission and non-goals
- [gameplay-experience.md](design/gameplay-experience.md) — what good bot chat looks like
- [npc-chat-behavior.md](design/npc-chat-behavior.md) — in-world character behavior rules
- [wow-3.3.5a-lore-and-world-context.md](design/wow-3.3.5a-lore-and-world-context.md) — WotLK lore baseline for prompts and RAG
- [openai-compatible-endpoints.md](design/openai-compatible-endpoints.md) — provider abstraction design
- [prompt-architecture.md](design/prompt-architecture.md) — prompt anatomy, placeholders, quality guidelines

### Implementation Plans
- [refactor-roadmap.md](plans/refactor-roadmap.md) — all 6 phases with dependencies and verification steps
- [testing-plan.md](plans/testing-plan.md) — build, runtime, and player-experience test scenarios
- [database-migration-plan.md](plans/database-migration-plan.md) — safe migration sequence and DB compatibility notes
- [api-compatibility-plan.md](plans/api-compatibility-plan.md) — provider abstraction implementation plan

### Operator Guides
- [installation.md](usage/installation.md) — build and install from scratch
- [configuration-guide.md](usage/configuration-guide.md) — every config key explained plainly
- [running-with-ollama.md](usage/running-with-ollama.md) — Ollama setup, models, network config
- [running-with-openai-compatible-api.md](usage/running-with-openai-compatible-api.md) — OpenAI-compatible endpoint setup *(stub — pending Phase 3B)*
- [testing-in-game.md](usage/testing-in-game.md) — manual test checklist for operators
- [troubleshooting.md](usage/troubleshooting.md) — symptom → cause → fix for known failures

---

## Phase 0 Definition of Done

Phase 0 (baseline documentation) is complete when:

1. `docs/current-state/` describes the repository as it exists today — every claim is source-backed, inferred, or unknown
2. `docs/design/` describes intended gameplay and architecture goals — clearly forward-looking, not current state
3. `docs/plans/` describes implementation steps without modifying any source file
4. `docs/usage/` gives enough operator guidance to build and run the current module
5. `evidence-map.md` traces every behavioral claim to a source file and function
6. `behavior-baseline.md` explicitly distinguishes working / partial / unknown feature status
