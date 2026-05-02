# Claude Code Harness — Evolution History (generalized)

An evolution log of the `.claude/` directory (hooks, agents, skills, rules). Domain-specific details such as module names and internal company systems have been stripped out, leaving only **why this structure evolved this way**.

> This harness started in a multi-stack monorepo (iOS / Next.js / Go) environment. The public version extracts only the Next.js / React / TypeScript parts.

---

## Phase 0 — Initial skeleton

The basic lifecycle and authoring principles were established.

> **`dev/active` → `dev/done` lifecycle**
> Once completed task folders pile up under `active/`, it becomes hard to visually distinguish them from in-progress work. After review with `/dev-update`, they are archived to `done/`.

> **`PROJECT_KNOWLEDGE.md` = "things you cannot learn by reading the code"**
> Only decisions, domain constraints, and known pitfalls are recorded. Letting the LLM manage feature lists or file inventories tends to drift away from the code — the code is treated as the source of truth.

---

## Phase 1 — Dropping the in-house matching engine and switching to native features

At this point, `.claude/` had bloated into a roughly 400-line in-house skill-matching engine (`skill-rules.json` + `UserPromptSubmit` hook + session flags). Once Claude Code natively supported description-based auto classification, the in-house engine was no longer necessary.

> **In-house engine → native auto classification**
> The structure ended up implementing the same feature twice — the maintenance cost of the in-house engine outweighed its value. With well-written `description` fields, matching accuracy was equivalent.
> **Result:** hooks 8 → 5, hook events 3 → 2, roughly 400 lines removed.

---

## Phase 2 — Multi-agent architecture (current skeleton)

A design doc was written to address seven accumulated problems from real usage in one shot, and then implemented sequentially. This phase is the current skeleton of the harness.

### Seven problems

1. Single Opus agent — chat / planning / coding / verification all handled by Opus. context rot + excess cost
2. Bloated `CLAUDE.md` — one file held all module rules in a monorepo, and every session loaded unrelated rules
3. One-shot `context.md` — generated only during full `/dev-docs` planning, never updated afterward
4. No global context — only feature-level context existed; the overall project state was hard to see
5. No sense of when to `/clear` — no visibility into remaining context
6. Missing middle tier — no lightweight mode between full planning and immediate coding
7. No verification gate — no way to enforce a build / stub check before declaring "done"

### Adopted architecture

```
User ─→ Opus (Coordinator: chat / judgment / dispatch / plan)
            ├─ implementer (Sonnet) — single task with fresh context
            ├─ verifier    (Sonnet) — independent plan-vs-code check
            ├─ auto-error-resolver  (Haiku)  — mechanical TS error fixes
            └─ frontend-error-fixer (Sonnet) — build / runtime diagnosis
```

### Core design decisions

> **No separate planner subagent** — the Coordinator runs the interview directly, so it already holds the requirements and decisions. Serializing that context and handing it off to a separate Opus would increase cost and introduce a re-interpretation risk.

> **`/dev-docs` BIG/SMALL/MICRO branching** — running every task through full planning was costly, but sending every task straight to implementation was also too blunt. Tasks are classified along five axes (file count / new files / layers / ambiguity / nature of change).

> **Four implementer status codes + handling matrix** — `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`. Without a matrix, the LLM falls back to situational ad-hoc judgment, which hurts consistency. Cognitive traps like "implementer said DONE, so I don't need to run the build" are blocked by rule.

> **Per-module `CLAUDE.md` + global `coordinator.md`** — leverages Claude Code's conditional loading of subdirectory `CLAUDE.md` files. Rules for unrelated modules are not loaded.

### Where the design came from

After reviewing patterns from GSD (`gsd-plan-checker`, `gsd-executor`, `gsd-context-monitor`) and Superpowers (`implementer-prompt`, `spec-compliance-reviewer`), only the parts that fit my workflow were extracted. Neither was adopted wholesale.

---

## Phase 3 — Audit and simplification

- `CLAUDE.md` 182 → 123 lines. Coordinator rules split out, duplicated sections removed.
- Removed the `python3` dependency → unified on `awk` / `bash` to avoid environment dependence.
- Inlined the `/dev-docs` EXIT GATE. Referencing it from a separate section was getting skipped by the LLM too often.

---

## Phase 4 — Pre-refactor snapshot

After codifying the seven accumulated problems, work moved on to Phase 5:

1. Seven `dev/*-context.md` files — bloated by repetitive filename listings, low value
2. `stop-context-update.sh` — directory mapping was outdated
3. `stop-context-summary-check.sh` — same as above
4. The Directory Structure section in the root `CLAUDE.md` was outdated
5. Four files under `.claude/rules/` were always loaded with no globs
6. No mechanism to enforce history records (relied on text rules)
7. No mechanism to block scope creep when handling requests without `/dev-docs`

---

## Phase 5 — Major refactor: context → history and hook redesign

### 5-1: context.md → history.md

> **Drop automatic shell-hook recording and let the AI write directly from its own context**
>
> In the previous structure, `stop-context-update.sh` automatically appended edited filenames to `dev/*-context.md`. The information that actually mattered (why / which decision / discarded approaches), however, was invisible to the shell hook.
>
> | Information type | shell hook access | AI access | Value |
> |------------------|:---:|:---:|------|
> | edited filenames | O | O | low (recoverable via `git log --stat`) |
> | **why it was done (motivation)** | **X** | **O** | **high** |
> | **which decision was made** | **X** | **O** | **high** |
> | **discarded approaches** | **X** | **O** | **high** |
>
> Conclusion: **the AI writes records directly from its conversation context**, and the shell hook only blocks when records are missing (enforcement gate). No transcript parsing or special tricks — the AI already has the relevant context.

### 5-2 ~ 5-4: structural cleanup

- Introduced per-module `CLAUDE.md` files, absorbed the per-module files under `.claude/rules/`, and then deleted those rule files (only `coordinator.md` stays global).
- Deleted two dead hooks (`stop-context-update.sh`, `stop-context-summary-check.sh`) — once their watch targets were gone, so was their reason to exist.
- Root `CLAUDE.md` 124 → 104 lines.

### 5-5: Commit format and history-writing principles

> **Enforce `[scope] type: one-line summary in Korean`** — existing messages had been all over the place (`Fix:`, `Task 4-5:`, `Update:`). Auto-extracting scope/type was hard. **A `commit-msg` hook was rejected** — since Claude is the one committing, a text rule was enough; a separate hook felt like overkill.

> **history = "only what cannot be recovered from git"** — record motivation / alternatives considered / decision rationale / failed attempts. Filename listings, diffs, and repeating commit messages are forbidden (recoverable via `git log --stat`). Append chronologically to the `## unsorted` section, and once entries pile up, sort them into Phases by hand.

### 5-8: stop hook state machine — two-stage commit and history enforcement

> **Use a per-session state file to work around the single-block limit of `stop_hook_active`**
> Official guidance recommends `exit 0` when `stop_hook_active: true` (to avoid infinite loops). But blocking only once made the two-stage check "first force commit → then force history" impossible.
> A per-session state file (`/tmp/claude-commit-history/{session_id}`) drives a small state machine: State 0 (initial) → State 1 (force commit) → State 2 (force history). A max retry count of 3 prevents infinite loops.

### 5-9: Removing six build-check hooks

> **They had been broken for weeks without causing issues → value-validation failure**
> The directory mapping in `post-tool-use-tracker.sh` had been outdated since a refactor → the four downstream hooks (`tsc`, `go-build`, `eslint`, `go-error`) had been broken for several weeks. No issues surfaced during that time.
> **Alternative (fix the paths) rejected:** my main work environment is long-build (e.g. mobile — `xcodebuild ~30s+`), so a stop-hook build is unrealistic. Coverage would have been less than half.
> **Replacement:** covered by text rules in `coordinator.md` and `CLAUDE.md`. A rule that both humans and the AI read was more robust in practice than a hook.

### 5-10: post-scope-escalation.sh — automatic scope escalation

> **Hard block when 3 or more module files are edited without `/dev-docs`**
> The "if scope grows, suggest `/dev-docs`" rule in `coordinator.md` was effectively a text-only warning, and the LLM could drop it during context compression. PostToolUse `decision: "block"` enforces it mechanically.
> Threshold: 1 file passes / 2 files trigger a soft warning / 3 or more files trigger a hard block. The counter resets when a `git commit` is detected (new work cycle).

### 5-12: Dropping separate hook docs

> **Deleted `SETUP.md`, `README.md`, `CONFIG.md` → inlined into top-of-file comments in each hook**
> The three docs needed to be kept in sync on every hook addition or removal. Outdated docs were worse than no docs in this context. Each hook file now declares its role / exit codes / input at the top — a single source of truth.

---

## Phase 6 — Preparing for public release

The internal harness was extracted for public release, with domain-specific information removed and the narrative tightened.

> **stack-agnostic → Next.js / React / TypeScript / pnpm lock-in**
> A sharp first impression mattered for the public version. "Stack-agnostic" was vague and hard to demonstrate. Accepting a narrower audience (Go / Swift / Python users) in exchange for a sharper pitch was the better tradeoff. The README explicitly states early on that "the patterns are stack-agnostic, but the bundled agents assume Next.js" — for other stacks, swap the implementation details.

> **planner agent removed — consistency cleanup**
> Despite the Phase 2 decision, `planner.md` was still around and created contradictions across `CLAUDE.md` / `README.md` / the agents README. Plan-writing responsibility belongs to the `dev-docs` skill.

> **Scope auto-extraction helper (`scope-for-staged.sh`) — the final piece of commit-format enforcement**
> The `[scope]` enforcement from Phase 5-5 still required the committer to type it correctly every time → typos and omissions could silently pass the stop hook.
> The helper auto-maps the top-level directory of staged files to `dir_to_scope`. If multiple modules are staged together, the commit is rejected, forcing a split.
> **Stop-hook reinforcement in parallel:** if a recent commit (within 5 minutes) lacks the prefix, reject it and print the amend command. **Defense in two layers — pre-automation (helper) + post-verification (stop hook).**

> **`/dev-docs` skill shipped — generic version**
> Dropped domain keyword detection and kept only BIG/SMALL/MICRO classification plus the three plan/context/tasks templates. **STEP 1.5 (scope interview)** added: extending existing vs new · API change · external library · data fetching · non-functional requirements. The stack interview is gone, but the questions that drive classification quality were preserved.

> **`.claude` tracking disabled by default**
> Prevents users from self-blocking when editing settings right after cloning. The README has an "(optional) enable harness self-tracking" section so it can be turned on after stabilization.

> **Codifying the two-layer persistence model (commit vs history)**
> commit (pushed) = WHAT summary / external audience / scope auto-extracted. history (`.gitignore`) = WHY / discarded alternatives / AI context + personal working notebook. This separation lets the history layer stay intentionally messy. Stating this near the top of the README pre-empts the "why isn't this pushed?" question.

---

## Key Decisions

| Decision | One-line rationale |
|----------|--------------------|
| Native auto classification | A well-written `description` field is enough — an in-house engine is unnecessary. Roughly 400 lines removed |
| Coordinator + subagents | Resolves single-Opus context rot and cost. Fresh context per task |
| No planner agent | The Coordinator already holds the interview context → avoid serialization cost |
| `/dev-docs` BIG/SMALL/MICRO | Fills the missing lightweight tier between full planning and immediate coding |
| Per-module `CLAUDE.md` > rules/ + globs | Equivalent official behavior, more natural for a module-based structure |
| **History is written by Claude directly** | Shell hooks cannot access conversation context |
| State machine for two-stage enforcement | Works around `stop_hook_active`'s single-block limit |
| Removed all build-check hooks | They ran broken without causing issues → value-validation failure |
| `commit-msg` hook rejected | Claude is the one committing, so text rules suffice |
| Scope escalation = PostToolUse block | Mechanical enforcement instead of relying on a text Red Flag |
| `scope-for-staged.sh` helper | Pre-automation + stop-hook post-verification (two-layer defense) |
| Next.js/TS lock-in (public) | Sharper pitch + demoability |

---

## Dead ends (do not re-explore)

| Approach | Why it was dropped |
|----------|--------------------|
| In-house skill-matching engine | Native gives equivalent functionality |
| python3 hooks | Environment dependence; awk/bash are enough |
| Auto-recording history via shell hooks | No access to conversation context |
| Build-check stop hooks | Outdated paths + poor coverage for long builds + ran broken without causing issues |
| `post-tool-use-tracker.sh` | Once all downstream hooks were removed, it had no reason to exist |
| `commit-msg` hook | Overkill because Claude is the one committing |
| Running `/dev-docs` directly from a hook | Official constraints — only guidance is possible |
| Quality-checking history content from a hook | Shell hooks can only check whether a record exists |
| `.agents/skills/` path | Not officially recognized; symlink git management overhead |
| Separate hook docs (SETUP/README/CONFIG) | Sync cost was too high; replaced with top-of-file comments |
| Separate `planner` subagent | The Coordinator already holds the interview context |
| `transcript_path` trick for auto-history | Having the AI write from its own context is simpler |
