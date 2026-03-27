# oc-profile

Switch between multiple auth profiles in [OpenCode](https://opencode.ai).

OpenCode stores a single active auth blob per installation. This script lets you save multiple auth profiles and switch between them safely.

## Install

```bash
# Copy somewhere on your PATH
cp oc-profile /usr/local/bin/
```

Or just run it directly from wherever you cloned it.

### Runtime dependencies

`oc-profile` requires these runtime tools:

- `jq >= 1.8` for canonical JSON integrity checks and state processing
- `flock` for safe locking on mutating commands

Install examples:

```bash
# Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y jq util-linux

# Arch Linux
sudo pacman -S --needed jq util-linux

# macOS (Homebrew)
brew install jq util-linux
```

Failure behavior:

- In strict mode (default), if `jq` is missing/unusable/older than `1.8`, commands that require it fail with deterministic exit code `13` and install guidance.
- If `flock` is unavailable, mutating commands (`init`, `make`, `switch`, `rename`, `delete`, `migrate`) fail fast because safe lock acquisition is not possible.
- `--skip-checks` enables compatibility mode. Commands that require unavailable `jq`/`flock` capabilities fail deterministically with exit code `15`. In this mode, `jq` capability means a usable `jq` binary (the strict `>= 1.8` version floor is not enforced).
- `--always-checks` always takes precedence over `--skip-checks` when both are present.
- `help` and `version` remain capability-exempt in compatibility mode.

## Setup

```bash
# 1. First run only: initialize the fresh layout
oc-profile init

# 2. Open opencode and run /connect with account A
# 3. Save it as a profile
oc-profile make work --current

# 4. Open opencode and run /connect with account B
# 5. Save it as a profile
oc-profile make personal --current
```

You now have two profiles. Switch between them anytime:

```bash
oc-profile switch work
# restart opencode
```

If commands report a legacy layout requirement, run:

```bash
oc-profile migrate
```

If commands report a fresh environment requirement (first run), run:

```bash
oc-profile init
```

### Initialization vs migration

`oc-profile` uses explicit layout states:

- **Fresh layout**: first-run environment -> run `oc-profile init`
- **Legacy layout**: old on-disk format -> run `oc-profile migrate`
- **Initialized layout**: expected modern tree -> normal commands work

## Commands

| Command | Description |
|---|---|
| `init` | Initialize a fresh environment into the v0.1.0 stateful layout (creates `default` when existing auth is present) |
| `make <name> --current` | Save current auth as a named profile and set it active |
| `make <name>` | Create an empty placeholder profile (allowed only after a first saved profile exists) |
| `save <name>` | Update an existing saved profile from current live auth |
| `save <name> --set-active` | Update an existing saved profile and set it active |
| `migrate` | Migrate legacy layout to the v0.1.0 stateful layout |
| `switch <name>` | Switch to a profile (requires restart) |
| `switch <name> --allow-empty-target` | Explicitly allow switching to an empty `{}` placeholder profile |
| `list` | List all profiles |
| `list --details` | List profiles with hash, mtime, and provider summary |
| `which` | Print the active profile name |
| `rename <old> <new>` | Rename a profile |
| `delete <name>` | Delete a profile |
| `version` / `--version` | Print CLI version |
| `help` / `help <command>` | Show global help or command-specific help |

Aliases: `ls` for `list`, `rm` for `delete`, `mv` for `rename`.

Command-specific help examples:

```bash
oc-profile help make
oc-profile make --help
oc-profile switch --help
```

Unknown help topics fail with a non-zero exit status.

## Options

| Option | Description |
|---|---|
| `--skip-checks` | Compatibility mode; fails with exit code `15` when required `jq`/`flock` capability is unavailable for the requested command. |
| `--always-checks` | Force strict mode (default); takes precedence when both strict/skip flags are passed. |
| `--dry-run` | Show planned actions without executing. |
| `-v`, `--verbose` | Enable verbose output. |
| `-vv` | Enable extra verbose output. |

Command-local flags:

- `make`: `--current`
- `save`: `--set-active`
- `switch`: `--save-current`, `--no-save-current`, `--trust-mismatch`, `--abort-on-mismatch`, `--allow-empty-target`
- `list`: `--details`, `--detail`, `-a`

Environment variables:
- `OC_PROFILE_SKIP_CHECKS=true` — Enable skip-checks mode (alternative to flag)
- `OC_PROFILE_JQ=/path/to/jq` — Use specific jq binary

### Dry-Run Mode

Use `--dry-run` with any mutating command to preview actions without executing:

```bash
oc-profile switch work --dry-run
oc-profile make personal --current --dry-run
oc-profile delete old-profile --dry-run
```

Dry-run executes the same validation and decision path as a real run (including lock acquisition), but suppresses filesystem/state mutations. Use `-v` or `-vv` for more detail.

### Option placement and ownership

`oc-profile` supports GNU-style option placement for global and command-local flags:

```bash
oc-profile switch work --save-current -v
oc-profile --dry-run --save-current switch work -v
oc-profile -av list
```

Invalid flag ownership fails deterministically with `error: unknown flag '<flag>'`.

### First profile safety

To prevent accidental credential loss on first setup:

- `init` promotes existing `auth.json` to `profiles/auth.active.json` and creates `profiles/default.json` when credentials are non-empty.
- The first saved profile must be created from live credentials with `make <name> --current`.
- Placeholder creation (`make <name>`) is blocked until at least one saved profile exists.

### Verbose Output

- `-v` / `--verbose`: Show command progress and key steps
- `-vv`: Show detailed context (file paths, lock info, dependency checks)

Examples:
```bash
# Normal switch
oc-profile switch work

# Verbose switch
oc-profile switch work -v

# Extra verbose switch
oc-profile switch work -vv

# Verbose dry-run
oc-profile switch work -vv --dry-run
```

## How it works

`oc-profile` keeps OpenCode reading from a stable live credentials file while tracking saved profile integrity in a separate state file.

```
~/.local/share/opencode/
├── auth.json -> profiles/auth.active.json
├── oc-profile.json
└── profiles/
    ├── auth.active.json
    ├── work.json
    └── personal.json
```

Behavior summary:

- `auth.json` stays a symlink to `profiles/auth.active.json` (the live file OpenCode uses).
- Saved profiles live in `profiles/<name>.json`.
- `oc-profile.json` records active profile plus canonical SHA-256 hashes for integrity checks.
- `switch` copies the selected saved profile into `auth.active.json` atomically, then updates state.

If your environment is on the legacy layout, run `oc-profile migrate` first.

If your environment is fresh (first run, no known profiles), run `oc-profile init` first.

Since OpenCode reads auth at startup, restart OpenCode after switching.

## Safety

- Cannot delete the last remaining profile
- Cannot delete the currently active profile
- Uses lock-based coordination for mutating operations
- Uses canonical hash checks and explicit trust flow on profile mismatch
- Requires explicit opt-in (`--allow-empty-target`) to switch into empty `{}` placeholder profiles in non-interactive sessions
- Fails fast in non-interactive sessions when a prompt would be required
- Creates a one-time bootstrap backup during migration
- Warns if OpenCode is running when you switch (restart required to apply)
- Validates profile names (alphanumeric, hyphens, underscores)

## Note on token expiry

OAuth tokens expire. OpenCode refreshes the active profile's token automatically, but a saved profile you haven't used in a while may go stale. If that happens, switch to it, run `/connect` again in OpenCode, and re-save with `make <name> --current`.

If the profile already exists, use `save <name>` instead of recreating it.

## Testing

This project uses [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) for testing.

### Setup

After cloning the repository, initialize the git submodules:

```bash
git submodule update --init --recursive
```

### Run Tests

```bash
./test/run-tests.sh
```

Or run a specific suite file:

```bash
./test/bats/bin/bats test/oc_profile_switch.bats
```

Suite files are split by concern for maintainability:
`test/oc_profile_core.bats`, `test/oc_profile_switch.bats`,
`test/oc_profile_migrate_lock.bats`, `test/oc_profile_crud.bats`,
`test/oc_profile_security.bats`, `test/oc_profile_edge.bats`,
and `test/oc_profile_multi_provider.bats`.

### Test Coverage

The test suite covers:

- Basic command functionality (help, invalid commands)
- Profile creation (`make`)
- Profile switching (`switch`)
- Profile listing (`list`)
- Profile deletion (`delete`)
- Profile renaming (`rename`)
- Active profile detection (`which`)
- Known security bugs (tests document expected behavior)
- Multi-provider `auth.json` blobs (see below)

### Multi-provider auth fixtures

OpenCode's `auth.json` is a `Record<providerId, Oauth | Api | WellKnown>` object (see
[`packages/opencode/src/auth/index.ts`](https://github.com/sst/opencode/blob/dev/packages/opencode/src/auth/index.ts)).
`oc-profile` treats the file as an opaque blob (copy / canonical-hash / switch), so the
tests exercise full realistic files rather than single-provider stubs.

#### Simulated credential convention

Every test credential string is generated as **`oc_test_` + 32-hex SHA-256 suffix** seeded
by a deterministic label so values are reproducible within a run but obviously non-production:

```bash
sim_token "label"           # → oc_test_<sha256(label)[0:32]>
```

The `build_multi_provider_auth_json [seed]` helper in `test/test_helper.bash` builds a
"kitchen-sink" object containing one entry per structural variant:

| Provider key      | Auth type   | Credential fields            |
|-------------------|-------------|------------------------------|
| `openai`          | `oauth`     | `access`, `refresh`, `expires`, `accountId` |
| `anthropic`       | `oauth`     | `access`, `refresh`, `expires` |
| `github-copilot`  | `oauth`     | `access`, `refresh`, `expires`, `enterpriseUrl` |
| `amazon-bedrock`  | `api`       | `key`                        |
| `gitlab`          | `api`       | `key`                        |
| `nvidia`          | `api`       | `key`                        |
| `huggingface`     | `api`       | `key`                        |
| `openrouter`      | `api`       | `key`                        |
| `mistral`         | `wellknown` | `key`, `token`               |

Structural ideas were borrowed from OpenCode's own test files (for reference only — this
repo does **not** run OpenCode's Bun test suite):

- OAuth shape — `packages/opencode/test/provider/gitlab-duo.test.ts`
- API key (bearer / PAT) — `packages/opencode/test/provider/amazon-bedrock.test.ts`
- Schema decode — `packages/opencode/test/util/effect-zod.test.ts`
- Provider IDs — `packages/opencode/src/provider/schema.ts`

A static template (`test/fixtures/auth/kitchen-sink.json.tpl`) documents the sentinel
names (`__SIM_*__`) that the helper replaces at test-setup time, making the committed file
structure-only with no real or sensitive-looking strings.

### CI/CD

Tests are automatically run on:

- Every push to `main` or `test` branches
- Every pull request to `main`

See `.github/workflows/test.yml` for CI configuration.

## License

MIT
