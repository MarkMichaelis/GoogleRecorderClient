# GoogleRecorderClient — Copilot Workspace Instructions

## Project Overview

GoogleRecorderClient is a web application that interfaces with Google Recorder.
This is a modern front-end web project using HTML, CSS, and JavaScript/TypeScript.

## Development Philosophy

1. **Test-Driven Development (TDD)** — Write tests before implementation code.
2. **Functional Web Testing** — Validate user-facing behavior with browser-level tests.
3. **Continuous Refactoring** — Eliminate duplication after every green step.

## Code Style

- **Favor TypeScript (`.ts`) over JavaScript (`.js`)** — all new source and test files must be written in TypeScript. Only generate `.js` files via compilation, never by hand.
- After **every step** (RED, GREEN, REFACTOR, or any code change), run `npx tsc` to compile TypeScript to JavaScript and verify there are no type errors. Fix any compiler errors before proceeding.
- Prefer `const` / `let`; never `var`.
- Use ES modules (`import` / `export`).
- Keep functions small (≤ 20 lines) and single-purpose.
- Name files in kebab-case; name classes in PascalCase; name functions/variables in camelCase.
- Every public function must have a JSDoc comment.

## Testing Conventions

| Layer | Tool | Location |
|---|---|---|
| Unit tests | Vitest | `tests/unit/**/*.test.ts` |
| Functional / E2E | Playwright | `tests/e2e/**/*.spec.ts` |

- Unit test files mirror the source tree (e.g., `src/utils/recorder.ts` → `tests/unit/utils/recorder.test.ts`).
- Functional tests are organized by feature / user flow.

## Product Specification

Maintain a living product specification in `docs/product-spec.md`.

- **Update the spec with every feature** — when a new behavior is implemented, document it in the spec.
- **When a requirement changes, update the spec to reflect the final behavior** — do not keep outdated requirements. The spec always describes the current state of the product, not its history.
- **Replace superseded acceptance criteria** — if a feature's behavior is modified, rewrite the acceptance criteria to match the new behavior. Remove or revise any criteria that no longer apply.
- The spec is the single source of truth for what the application **currently** does.
- Sections: Overview, Features (with acceptance criteria), API Surface, UI Flows, Data Model, Known Limitations.
- Use Conventional Commits for spec changes: `docs(spec): add <feature> specification` or `docs(spec): update <feature> specification`.

## Branching Strategy

- **Never commit directly to `main`.** Always create a feature branch first.
- Branch naming: `<agent-name>/<type>/<short-description>` — prefix with the agent/model name.
  Examples: `Opus.4.6/feat/audio-playback`, `Opus.4.6/fix/transcript-encoding`.
- All work happens on the feature branch. Merge to `main` only via pull request after the dev loop passes.

## Commit Messages

Follow Conventional Commits: `type(scope): description`

Types: `feat`, `fix`, `test`, `refactor`, `docs`, `chore`.

## Agent Files

Dedicated agent prompts live in `.github/agents/` using the `.agent.md` format:

| Agent | Purpose |
|---|---|
| `tdd.agent.md` | Red → Green → Refactor cycle for Vitest unit tests |
| `web-testing.agent.md` | Generate & maintain Playwright functional tests |
| `refactor.agent.md` | Identify and remove duplication after each green step |
| `code-review.agent.md` | Independent code review using a different LLM (`o4-mini`) |
| `dev-loop.agent.md` | Orchestrator: TDD → Refactor → Web Test → Review → Fix → Repeat |

### Development Workflow

Use `@dev-loop` to drive the full quality cycle for any feature. It coordinates
all other agents in order and repeats until the code review passes cleanly.

```
TDD (Red→Green) → Refactor → Web Test → Code Review (o4-mini) → Fix → Re-Review
```
