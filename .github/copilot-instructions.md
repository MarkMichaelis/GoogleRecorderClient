# GoogleRecorderClient — Copilot Workspace Instructions

## Project Overview

GoogleRecorderClient is a **PowerShell module** that interfaces with the Google Recorder gRPC-Web API at `recorder.google.com`. It provides cmdlets for authentication and recording management.

## Language Detection

Detect the project's primary language from its files and apply the matching guidance below. When multiple languages coexist, apply each language's rules to the files of that language.

| Indicator files | Language |
|---|---|
| `.ps1`, `.psm1`, `.psd1` | PowerShell |
| `.ts`, `.js`, `package.json`, `tsconfig.json` | TypeScript / JavaScript |
| `.py`, `pyproject.toml`, `setup.py` | Python |
| `.cs`, `.csproj`, `.sln` | C# / .NET |
| `.go`, `go.mod` | Go |
| `.rs`, `Cargo.toml` | Rust |
| `.java`, `pom.xml`, `build.gradle` | Java |

If the language is not listed, infer conventions from the project's existing code, README, and build files.

## Development Philosophy

1. **Test-Driven Development (TDD)** — Write tests first, always. No production code without a failing test.
2. **Systematic over ad-hoc** — Process over guessing. Follow structured workflows.
3. **Complexity reduction** — Simplicity as primary goal. YAGNI ruthlessly.
4. **Evidence over claims** — Verify before declaring success. Run commands, read output, present facts.
5. **Functional Testing** — Validate user-facing behavior with integration or end-to-end tests.
6. **Continuous Refactoring** — Eliminate duplication after every green step.

## Code Style — Generic (All Languages)

- Keep functions / methods small (≤ 20 lines) and single-purpose.
- Prefer immutable variables where the language supports them.
- Every public function must have a documentation comment (doc-comment, JSDoc, XML doc, comment-based help, etc.).
- Follow the language's established naming, formatting, and module conventions.
- Use the project's existing linter / formatter. Run it after every change.
- After **every step** (RED, GREEN, REFACTOR, or any code change), run the project's compile/lint command and verify there are no errors. Fix any errors before proceeding.

## Code Style — PowerShell

- All new source and test files must be `.ps1` / `.psm1` / `.psd1`.
- Follow the **Verb-Noun** naming convention for functions (`Get-GoogleRecording`, `Connect-GoogleRecorder`).
- Name files in **PascalCase** matching the function name (e.g., `Get-GoogleRecording.ps1`).
- Use **comment-based help** (`<# .SYNOPSIS ... #>`) for every exported function.
- Use `$ErrorActionPreference = 'Stop'` in scripts; prefer `-ErrorAction Stop` on individual calls.
- After every step, run `Invoke-ScriptAnalyzer` to check for lint issues and `Import-Module ... -Force` to verify the module loads:
  ```powershell
  Invoke-ScriptAnalyzer -Path src/ -Recurse -Severity Warning
  Import-Module ./src/GoogleRecorderClient/GoogleRecorderClient.psd1 -Force -ErrorAction Stop
  ```
- Prefer `[CmdletBinding()]` and `param()` blocks for all functions.
- Use **approved verbs** only (`Get-Verb` to list them).

## Code Style — TypeScript / JavaScript

- Favor TypeScript (`.ts`) over JavaScript (`.js`).
- After every step, run `npx tsc` to verify there are no type errors.
- Prefer `const` / `let`; never `var`.
- Use ES modules (`import` / `export`).
- Name files in kebab-case; classes in PascalCase; functions/variables in camelCase.
- Every public function must have a JSDoc comment.

## Testing Conventions — Generic

- **Unit tests** mirror the source tree.
- **Test files live in a `tests/` directory** (or the language's conventional location).
- Use the project's established test framework. If none exists, choose the community standard for the language.
- Functional / integration tests are organized by feature or user flow.

## Testing Conventions — PowerShell

| Layer | Tool | Location |
|---|---|---|
| Unit tests | Pester | `tests/unit/**/*.Tests.ps1` |
| Integration tests | Pester | `tests/integration/**/*.Tests.ps1` |

- Unit test files mirror the source tree (e.g., `src/GoogleRecorderClient/Public/Get-GoogleRecording.ps1` → `tests/unit/Public/Get-GoogleRecording.Tests.ps1`).
- Run tests with:
  ```powershell
  Invoke-Pester -Path tests/ -Output Detailed
  ```
- Mock external dependencies with Pester's `Mock` command. Use real code paths wherever possible.

## Testing Conventions — TypeScript / JavaScript

| Layer | Tool | Location |
|---|---|---|
| Unit tests | Vitest | `tests/unit/**/*.test.ts` |
| Functional / E2E | Playwright | `tests/e2e/**/*.spec.ts` |

- Run tests with:
  ```bash
  npx tsc && npx vitest run
  npx playwright test
  ```

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
| `brainstorming.agent.md` | Socratic design refinement — explore intent, propose approaches, get approval before coding |
| `tdd.agent.md` | Red → Green → Refactor cycle with Iron Law enforcement (no code without failing test) |
| `functional-testing.agent.md` | Generate & maintain functional / E2E tests with verification-before-completion |
| `refactor.agent.md` | Identify and remove duplication after each green step — YAGNI, simplicity first |
| `code-review.agent.md` | Independent code review using a different LLM (`o4-mini`) with severity-based findings |
| `systematic-debugging.agent.md` | 4-phase root cause investigation — no fixes without understanding the problem first |
| `dev-loop.agent.md` | Orchestrator: Brainstorm → Plan → TDD → Refactor → Functional Test → Verify → Review → Fix → Repeat |

### Development Workflow

Use `@dev-loop` to drive the full quality cycle for any feature. It coordinates
all other agents in order and repeats until the code review passes cleanly.

```
Brainstorm → Plan → TDD (Red→Green) → Refactor → Functional Test → Verify → Code Review (o4-mini) → Fix → Re-Review
```

Use `@brainstorming` when exploring a new idea before committing to implementation.
Use `@systematic-debugging` when encountering any bug or unexpected behavior.
