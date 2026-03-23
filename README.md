# oc-profile

Switch between multiple OpenAI subscription accounts (ChatGPT Plus/Pro) in [OpenCode](https://opencode.ai).

OpenCode stores a single set of OAuth credentials per provider. This script lets you save multiple OpenAI auth profiles and swap between them via symlink.

## Install

```bash
# Copy somewhere on your PATH
cp oc-profile /usr/local/bin/
```

Or just run it directly from wherever you cloned it.

## Setup

```bash
# 1. Open opencode → /connect → OpenAI → ChatGPT Plus/Pro → sign in with account A
# 2. Save it as a profile
oc-profile make work --current

# 3. Open opencode → /connect → OpenAI → ChatGPT Plus/Pro → sign in with account B
# 4. Save it as a profile
oc-profile make personal --current
```

You now have two profiles. Switch between them anytime:

```bash
oc-profile switch work
# restart opencode
```

## Commands

| Command | Description |
|---|---|
| `make <name> --current` | Save current auth as a named profile and set it active |
| `make <name>` | Create an empty placeholder profile |
| `switch <name>` | Switch to a profile (requires restart) |
| `list` | List all profiles |
| `which` | Print the active profile name |
| `rename <old> <new>` | Rename a profile |
| `delete <name>` | Delete a profile |
| `help` | Show help |

Aliases: `ls` for `list`, `rm` for `delete`, `mv` for `rename`.

## How it works

Profiles are stored as JSON files in `~/.local/share/opencode/profiles/`. The script turns `~/.local/share/opencode/auth.json` into a symlink pointing to the active profile. Switching just repoints the symlink. All non-OpenAI credentials (Anthropic, Copilot, etc.) are unaffected.

```
~/.local/share/opencode/
├── auth.json -> profiles/work.json   # symlink
└── profiles/
    ├── work.json
    └── personal.json
```

Since OpenCode reads auth at startup, you need to restart it after switching.

## Safety

- Cannot delete the last remaining profile
- Cannot delete the currently active profile
- Backs up `auth.json` automatically on first switch if it's a regular file
- Warns if OpenCode is running when you switch
- Validates profile names (alphanumeric, hyphens, underscores)

## Note on token expiry

OAuth tokens expire. OpenCode refreshes the active profile's token automatically, but a saved profile you haven't used in a while may go stale. If that happens, switch to it, run `/connect` again in OpenCode, and re-save with `make <name> --current`.

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
