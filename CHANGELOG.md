# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- No unreleased changes.

## [0.1.0-rc.1] - 2026-03-24

### Added
- Stateful auth layout using `profiles/auth.active.json` plus `oc-profile.json` metadata tracking.
- Explicit `migrate` command to move legacy layouts into the current model.
- Explicit `init` command for fresh first-run environments with backup-first promotion when an existing regular `auth.json` file is present.
- Deterministic exit codes for migration requirements, prompt-required non-interactive flows, hash-mismatch refusal, jq dependency checks, and lock contention.
- BATS suite split by concern (`core`, `switch`, `migrate_lock`, `crud`, `security`, `edge`, `multi_provider`) and multi-provider auth fixture coverage.
- CI workflow to run BATS tests on push/PR.
- `--skip-checks` flag to bypass runtime dependency checks (jq, flock) for environments where these tools are unavailable.
- `--always-checks` flag to force strict mode (default behavior).
- `OC_PROFILE_SKIP_CHECKS=true` environment variable for non-interactive pipelines.
- Explicit layout-state classifier (`fresh`, `legacy`, `initialized`, `broken`) to route operators to `init` vs `migrate` deterministically.

### Changed
- Switching now updates live credentials by atomically copying into `profiles/auth.active.json` and refreshing state metadata.
- Integrity checks compare canonical JSON hashes and require explicit trust when recorded and current target hashes differ.
- Non-interactive switch behavior now fails fast when operator prompts would otherwise be required.
- Test naming and section comments were cleaned to remove session-artifact wording.
- Install/setup documentation now explicitly declares runtime dependencies (`jq >= 1.8`, `flock`) and dependency-related failure behavior.
- Renamed `--unsafe` mode to `--skip-checks` for clearer semantics.
- Refactored `--dry-run` to use inline execution-path gating so runtime validations and lock flow match real execution while mutating operations are suppressed.
- Expanded flag-focused BATS coverage for inline dry-run behavior, side-effect suppression, grouped verbosity parsing, and first-run guard behavior.
- Fresh first-run initialization now auto-creates `default` from existing non-empty credentials during `init`.
- First placeholder profile creation is now blocked until an operator saves one real profile with `make <name> --current`.
- Mutating commands now require initialized layout and return deterministic `init required` guidance on fresh environments.
- Strict-mode dependency enforcement now requires `jq >= 1.8` with explicit install guidance.

### Security
- Preserved target-profile tamper detection ordering during dirty-active save flows by capturing target recorded hash before state rebuild.
- Added regression coverage for hash-mismatch and dirty-active interaction paths.

[Unreleased]: #unreleased
[0.1.0-rc.1]: #010-rc1---2026-03-24
