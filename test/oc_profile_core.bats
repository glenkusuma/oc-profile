#!/usr/bin/env bats
# Core command tests for oc-profile

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

run_with_minimal_path() {
  local path_value="$1"
  shift
  run env PATH="${path_value}" "$@"
}

empty_bin_path() {
  local dir="${BATS_TEST_TMPDIR}/empty-bin"
  mkdir -p "${dir}"
  echo "${dir}"
}

# ──────────────────────────────────────────────────────────────
# Basic command tests
# ──────────────────────────────────────────────────────────────

@test "help command shows usage" {
  run "$OC_PROFILE" help
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "COMMANDS"
}

@test "help command supports command topic" {
  run "$OC_PROFILE" help make
  assert_success
  assert_output --partial "usage: oc-profile make <name> [--current]"
}

@test "help command supports save topic" {
  run "$OC_PROFILE" help save
  assert_success
  assert_output --partial "usage: oc-profile save <name> [--set-active]"
}

@test "help command rejects unknown topic with non-zero" {
  run "$OC_PROFILE" help unknown-topic
  assert_failure
  assert_output --partial "unknown help topic 'unknown-topic'"
}

@test "version flag prints version" {
  run "$OC_PROFILE" --version
  assert_success
  assert_output "0.1.0-rc.1"
}

@test "invalid command shows error" {
  run "$OC_PROFILE" invalid-command
  assert_failure
  assert_output --partial "unknown command"
}

# ──────────────────────────────────────────────────────────────
# Basic commands
# ──────────────────────────────────────────────────────────────

@test "help flag shows help" {
  run "$OC_PROFILE" --help
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "COMMANDS"
}

@test "make --help shows subcommand usage" {
  run "$OC_PROFILE" make --help
  assert_success
  assert_output --partial "usage: oc-profile make <name> [--current]"
}

@test "save --help shows subcommand usage" {
  run "$OC_PROFILE" save --help
  assert_success
  assert_output --partial "usage: oc-profile save <name> [--set-active]"
}

@test "switch --help shows subcommand usage" {
  run "$OC_PROFILE" switch --help
  assert_success
  assert_output --partial "usage: oc-profile switch <name>"
}

@test "switch usage includes allow-empty-target option" {
  run "$OC_PROFILE" switch
  assert_failure
  assert_output --partial "--allow-empty-target"
}

@test "no arguments shows help" {
  run "$OC_PROFILE"
  assert_success
  assert_output --partial "USAGE"
}

# ──────────────────────────────────────────────────────────────
# init
# ──────────────────────────────────────────────────────────────

@test "init creates initialized layout on fresh environment" {
  setup_fresh_layout

  run "$OC_PROFILE" init
  assert_success
  assert_output --partial "initialized fresh layout"

  assert_file_exist "${STATE_FILE}"
  assert_file_exist "${ACTIVE_CREDENTIALS_FILE}"
  assert [ -L "${AUTH_FILE}" ]
  readlink "${AUTH_FILE}" | grep -q "profiles/auth.active.json"
}

@test "init backs up existing regular auth.json and promotes it to active" {
  setup_fresh_layout_with_auth_file
  local before
  before="$(cat "${AUTH_FILE}")"

  run "$OC_PROFILE" init
  assert_success
  assert_output --partial "initialized fresh layout"

  assert [ -L "${AUTH_FILE}" ]
  local after
  after="$(cat "${ACTIVE_CREDENTIALS_FILE}")"
  assert [ "${before}" = "${after}" ]
  assert_file_exist "${PROFILES_DIR}/default.json"

  run "$OC_PROFILE" which
  assert_success
  assert_output "default"

  run ls "${PROFILES_DIR}/.bootstrap-backup/"*_pre-init_auth.json
  assert_success
}

@test "init is idempotent on initialized layout" {
  run "$OC_PROFILE" init
  assert_success
  assert_output --partial "already initialized"
}

@test "strict minimal-PATH init fails with flock missing" {
  setup_fresh_layout_with_auth_file

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" init
  assert_failure
  assert [ "$status" -eq 1 ]
  assert_output --partial "flock not found"
}

@test "strict minimal-PATH init --dry-run -vv fails with flock missing" {
  setup_fresh_layout_with_auth_file

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" init --dry-run -vv
  assert_failure
  assert [ "$status" -eq 1 ]
  assert_output --partial "flock not found"
}

@test "strict minimal-PATH --always-checks init fails with flock missing" {
  setup_fresh_layout_with_auth_file

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --always-checks init
  assert_failure
  assert [ "$status" -eq 1 ]
  assert_output --partial "flock not found"
}

# ──────────────────────────────────────────────────────────────
# make
# ──────────────────────────────────────────────────────────────

@test "make creates profile from current live auth and sets active" {
  run "$OC_PROFILE" make work --current
  assert_success
  assert_output --partial "created profile 'work'"
  assert_file_exist "${PROFILES_DIR}/work.json"
  assert [ -L "${AUTH_FILE}" ]
}

@test "make placeholder is blocked before first saved profile exists" {
  run "$OC_PROFILE" make work
  assert_failure
  assert_output --partial "first profile must be saved from current credentials"
  assert_file_not_exist "${PROFILES_DIR}/work.json"
}

@test "make rejects invalid profile name" {
  run "$OC_PROFILE" make "invalid name"
  assert_failure
  assert_output --partial "invalid profile name"
}

@test "make rejects duplicate profile name" {
  run "$OC_PROFILE" make work --current
  assert_success
  run "$OC_PROFILE" make work --current
  assert_failure
  assert_output --partial "already exists"
}

# ──────────────────────────────────────────────────────────────
# make edge cases
# ──────────────────────────────────────────────────────────────

@test "make rejects empty profile name" {
  run "$OC_PROFILE" make ""
  assert_failure
  assert_output --partial "usage:"
}

@test "make --current fails when live credentials file is missing from initialized layout" {
  rm -f "${ACTIVE_CREDENTIALS_FILE}"
  run "$OC_PROFILE" make work --current
  assert_failure
  assert_output --partial "layout is inconsistent"
}

# ──────────────────────────────────────────────────────────────
# list / which
# ──────────────────────────────────────────────────────────────

@test "save updates existing profile from live credentials" {
  "$OC_PROFILE" make work --current
  simulate_connect "test-token-updated"

  run "$OC_PROFILE" save work
  assert_success
  assert_output --partial "saved current live credentials to 'work'"

  run jq -r '.openai.access' "${PROFILES_DIR}/work.json"
  assert_success
  assert_output "test-token-updated"

  run "$OC_PROFILE" which
  assert_success
  assert_output "work"
}

@test "save --set-active updates active_profile name" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch work --save-current
  simulate_connect "test-token-personal-new"

  run "$OC_PROFILE" save personal --set-active
  assert_success
  assert_output --partial "set as active"

  run "$OC_PROFILE" which
  assert_success
  assert_output "personal"
}

@test "save fails when profile does not exist" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" save missing
  assert_failure
  assert_output --partial "profile 'missing' does not exist"
}

@test "save fails when live credentials file is missing" {
  "$OC_PROFILE" make work --current
  rm -f "${ACTIVE_CREDENTIALS_FILE}"
  run "$OC_PROFILE" save work
  assert_failure
  assert_output --partial "live credentials file not found"
}

@test "list marks active profile" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch personal --save-current
  run "$OC_PROFILE" list
  assert_success
  assert_output --partial "* personal"
  assert_output --partial "(active)"
}

@test "which shows active profile" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" which
  assert_success
  assert_output "work"
}

@test "which fails when no active profile" {
  rm -f "${STATE_FILE}"
  run "$OC_PROFILE" which
  assert_failure
  assert_output --partial "no active profile found"
}

@test "which guidance is explicit when active name is empty and saved profiles exist" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch work --save-current
  jq '.active_profile = ""' "${STATE_FILE}" > "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "${STATE_FILE}"

  run "$OC_PROFILE" which
  assert_failure
  assert_output --partial "no active saved profile is set"
  assert_output --partial "save <existing-profile>"
}

# ──────────────────────────────────────────────────────────────
# list
# ──────────────────────────────────────────────────────────────

@test "list shows all profiles" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  run "$OC_PROFILE" list
  assert_success
  assert_output --partial "work"
  assert_output --partial "personal"
}

@test "list shows message when no profiles" {
  run "$OC_PROFILE" list
  assert_success
  assert_output --partial "no profiles saved"
}

@test "strict minimal-PATH pre-init list succeeds without profiles" {
  setup_fresh_layout

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" list
  assert_success
  assert_output --partial "no profiles saved yet"
}

@test "strict minimal-PATH pre-init ls alias succeeds without profiles" {
  setup_fresh_layout

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" ls
  assert_success
  assert_output --partial "no profiles saved yet"
}

@test "ls alias works for list" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" ls
  assert_success
  assert_output --partial "work"
}

@test "list guidance is explicit when active name is empty and profiles exist" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  jq '.active_profile = ""' "${STATE_FILE}" > "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "${STATE_FILE}"

  run "$OC_PROFILE" list
  assert_success
  assert_output --partial "no active saved profile is selected"
  assert_output --partial "save <existing-profile>"
}

@test "strict minimal-PATH delete returns fresh-layout guard with exit 16" {
  setup_fresh_layout

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" delete work
  assert_failure
  assert [ "$status" -eq 16 ]
  assert_output --partial "fresh environment detected; run 'oc-profile init' first."
}

@test "strict minimal-PATH rm alias returns fresh-layout guard with exit 16" {
  setup_fresh_layout

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" rm work
  assert_failure
  assert [ "$status" -eq 16 ]
  assert_output --partial "fresh environment detected; run 'oc-profile init' first."
}

@test "strict minimal-PATH --always-checks delete returns fresh-layout guard with exit 16" {
  setup_fresh_layout

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --always-checks delete work
  assert_failure
  assert [ "$status" -eq 16 ]
  assert_output --partial "fresh environment detected; run 'oc-profile init' first."
}

@test "strict minimal-PATH --always-checks rm alias returns fresh-layout guard with exit 16" {
  setup_fresh_layout

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --always-checks rm work
  assert_failure
  assert [ "$status" -eq 16 ]
  assert_output --partial "fresh environment detected; run 'oc-profile init' first."
}

@test "save in skip mode fails with exit 15 when jq capability is unavailable" {
  "$OC_PROFILE" make work --current
  export OC_PROFILE_JQ="/tmp/does-not-exist-jq"

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --skip-checks save work
  assert_failure
  assert [ "$status" -eq 15 ]
  assert_output --partial "operation 'save' requires jq and flock in --skip-checks mode; rerun without --skip-checks (or pass --always-checks)."
}
