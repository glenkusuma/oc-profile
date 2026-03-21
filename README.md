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

Or run specific test files:

```bash
./test/bats/bin/bats test/oc_profile.bats
```

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

### CI/CD

Tests are automatically run on:

- Every push to `main` or `test` branches
- Every pull request to `main`

See `.github/workflows/test.yml` for CI configuration.

## License

MIT
