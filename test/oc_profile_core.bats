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

# ──────────────────────────────────────────────────────────────
# Basic command tests
# ──────────────────────────────────────────────────────────────

@test "help command shows usage" {
  run "$OC_PROFILE" help
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "COMMANDS"
}

@test "version flag prints version" {
  run "$OC_PROFILE" --version
  assert_success
  assert_output "0.1.0"
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

@test "no arguments shows help" {
  run "$OC_PROFILE"
  assert_success
  assert_output --partial "USAGE"
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

@test "make creates empty placeholder without changing active when no active profile exists yet" {
  run "$OC_PROFILE" make work
  assert_success
  assert_file_exist "${PROFILES_DIR}/work.json"
  # In this stage, placeholder doesn't force active_profile unless --current is used.
  run "$OC_PROFILE" which
  assert_failure
  assert_output --partial "no active profile found"
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

@test "make --current fails when no live credentials file exists" {
  rm -f "${ACTIVE_CREDENTIALS_FILE}"
  run "$OC_PROFILE" make work --current
  assert_failure
  assert_output --partial "live credentials file not found"
}

# ──────────────────────────────────────────────────────────────
# list / which
# ──────────────────────────────────────────────────────────────

@test "list marks active profile" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal
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

@test "ls alias works for list" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" ls
  assert_success
  assert_output --partial "work"
}
