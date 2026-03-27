# AGENTS.md

Guidance for agentic coding assistants working in this repository.

This repo is a Bash CLI (`oc-profile`) with BATS tests and strict safety rules.

## Project Snapshot
- Main executable: `./oc-profile`
- Test framework: BATS (`./test/bats/bin/bats`)
- Test entrypoint: `./test/run-tests.sh`
- CI workflow: `.github/workflows/test.yml`
- Runtime deps: `jq >= 1.8`, `flock`

## Source of Truth (highest to lowest)
1. Runtime behavior in `./oc-profile`
2. `README.md`
3. `CHANGELOG.md`
4. `.cursor/plans/*.md` and `.cursor/review*/**`
5. `.tmp/**` notes (historical unless explicitly current)

## Rule Files Status
- No `.cursor/rules/**`
- No `.cursorrules`
- No `.github/copilot-instructions.md`

Do not invent missing Cursor/Copilot rules. Follow this file and in-repo docs/code.

## Setup
Initialize submodules after clone:

```bash
git submodule update --init --recursive
```

Check runtime tools:

```bash
command -v jq && jq --version
command -v flock
```

## Build / Lint / Test Commands
There is no compile/build step. Verification is shell checks + BATS.

Syntax check:

```bash
bash -n ./oc-profile
```

Lint:

```bash
shellcheck ./oc-profile
```

Run all tests:

```bash
./test/run-tests.sh
```

Run one suite file:

```bash
./test/bats/bin/bats test/oc_profile_flags.bats
```

Run one test case by name regex:

```bash
./test/bats/bin/bats test/oc_profile_flags.bats -f "strict mode enforces jq >= 1.8"
```

Count tests only:

```bash
./test/bats/bin/bats -c test/oc_profile_flags.bats
```

Verbose/diagnostic run:

```bash
./test/bats/bin/bats test/oc_profile_switch.bats --print-output-on-failure -T
```

## Required Single-Test Workflow
For behavior changes, run in this order:
1. Targeted case (`-f`) in nearest suite
2. Full impacted suite file
3. Full suite (`./test/run-tests.sh`)

## Safety-Critical Test Rule
Never run `./oc-profile` against a real `$HOME` during verification.
- Preferred: BATS (uses isolated HOME via `BATS_TEST_TMPDIR`)
- If manual execution is needed, set `HOME` to an isolated temp dir first

## Bash Code Style
### Shell baseline
- Use `#!/usr/bin/env bash`
- Use `set -euo pipefail`
- Use `[[ ... ]]` over `[ ... ]`
- Quote variables unless intentional splitting/globbing is required
- Use `local` inside functions

### Structure
- Keep helper functions small and single-purpose
- Prefer explicit command handlers (`cmd_*`) and deterministic dispatch
- Keep side effects at explicit boundaries (`run_mutation`, atomic helpers)
- Keep output through centralized helpers (`info`, `warn`, `success`, `die_with_code`)

### Naming and formatting
- Constants: `UPPER_SNAKE_CASE`
- Functions: `snake_case`
- Command handlers: `cmd_<verb>`
- Indentation: 2 spaces
- Keep comments only for non-obvious invariants/safety behavior

### Types, imports, and data handling
- Bash has no imports/types; use explicit helper contracts + validation
- Treat credential JSON as opaque content for copy/switch operations
- Use `jq` for canonicalization and state inspection
- Keep schema assumptions aligned with `state_is_valid` and README contracts

## Error Handling and Exit Codes
- Fail fast with `die_with_code` for known failure modes
- Preserve deterministic exit code behavior for automation
- Never print secrets/tokens in stdout/stderr
- Non-interactive prompt-required paths must fail with explicit non-zero status

## File and State Safety
- Acquire lock for mutating paths (except intentional skip-checks behavior)
- Use atomic write/copy patterns (temp file + move)
- Preserve secure permissions (`700` dirs, `600` files)
- Keep profile safety guards intact (last profile, active profile, unknown files)

## CLI and UX Consistency
- Use `oc-profile` as the canonical command name everywhere
- Keep README/help/test assertions aligned after output text changes
- Keep operator guidance deterministic and action-oriented (`run 'oc-profile init'`)

## Testing Style (BATS)
- Prefer deterministic assertions: stable substrings + explicit exit codes
- Prefer side-effect assertions over prose-only output checks
- Reuse fixtures in `test/test_helper.bash`
- Add new branch/flag coverage in the closest suite file

## Dependency and Compatibility Notes
- Canonical dependency floor: `jq >= 1.8`
- Treat older `.tmp` dependency notes as historical unless reconfirmed
- `--skip-checks` is compatibility mode; do not assume jq-free behavior

## Documentation Sync Rules
When behavior changes:
1. Update `README.md`
2. Update `CHANGELOG.md` in the correct release bucket
3. Re-check impacted test assertions for user-facing text

Keep runtime output, docs, and tests aligned before finishing.
