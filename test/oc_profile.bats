#!/usr/bin/env bats
# Test suite for oc-profile

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

# ═══════════════════════════════════════════════════════════════
# Basic Command Tests
# ═══════════════════════════════════════════════════════════════

@test "help command shows usage" {
  run "$OC_PROFILE" help
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "COMMANDS"
}

@test "help flag shows help" {
  run "$OC_PROFILE" --help
  assert_success
  assert_output --partial "USAGE"
}

@test "no arguments shows help" {
  run "$OC_PROFILE"
  assert_success
  assert_output --partial "USAGE"
}

@test "invalid command shows error" {
  run "$OC_PROFILE" invalid-command
  assert_failure
  assert_output --partial "unknown command"
}

# ═══════════════════════════════════════════════════════════════
# Profile Creation Tests
# ═══════════════════════════════════════════════════════════════

@test "make creates profile from current auth" {
  run "$OC_PROFILE" make work --current
  assert_success
  assert_output --partial "created profile 'work'"
  assert_file_exist "${PROFILES_DIR}/work.json"
  assert [ -L "${AUTH_FILE}" ]
}

@test "make creates empty profile without --current" {
  run "$OC_PROFILE" make personal
  assert_success
  assert_output --partial "created empty profile 'personal'"
  assert_file_exist "${PROFILES_DIR}/personal.json"
  run cat "${PROFILES_DIR}/personal.json"
  assert_output "{}"
}

@test "make rejects invalid profile name" {
  run "$OC_PROFILE" make "invalid name"
  assert_failure
  assert_output --partial "invalid profile name"
}

@test "make rejects empty profile name" {
  run "$OC_PROFILE" make ""
  assert_failure
  assert_output --partial "usage:"
}

@test "make rejects duplicate profile name" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" make work --current
  assert_failure
  assert_output --partial "already exists"
}

@test "make fails when no auth.json exists" {
  rm -f "${AUTH_FILE}"
  run "$OC_PROFILE" make work --current
  assert_failure
  assert_output --partial "no auth.json found"
}

# ═══════════════════════════════════════════════════════════════
# Profile Switch Tests
# ═══════════════════════════════════════════════════════════════

@test "switch changes active profile" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  run "$OC_PROFILE" switch work
  assert_success
  assert_output --partial "switched to 'work'"
}

@test "switch reports when already on profile" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" switch work
  assert_success
  assert_output --partial "already on profile 'work'"
}

@test "switch fails for non-existent profile" {
  run "$OC_PROFILE" switch nonexistent
  assert_failure
  assert_output --partial "does not exist"
}

@test "switch backs up regular auth.json" {
  rm -rf "${PROFILES_DIR}"
  mkdir -p "${PROFILES_DIR}"
  rm -f "${AUTH_FILE}"
  echo '{"access_token":"original"}' > "${AUTH_FILE}"
  echo '{"access_token":"test"}' > "${PROFILES_DIR}/work.json"
  echo '{"access_token":"test"}' > "${PROFILES_DIR}/personal.json"
  run "$OC_PROFILE" switch personal
  assert_success
  assert_file_exist "${AUTH_DIR}/auth.json.backup"
}

# ═══════════════════════════════════════════════════════════════
# Profile List Tests
# ═══════════════════════════════════════════════════════════════

@test "list shows all profiles" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  run "$OC_PROFILE" list
  assert_success
  assert_output --partial "work"
  assert_output --partial "personal"
}

@test "list marks active profile" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch work
  run "$OC_PROFILE" list
  assert_success
  assert_output --partial "* work"
  assert_output --partial "(active)"
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

# ═══════════════════════════════════════════════════════════════
# Profile Delete Tests
# ═══════════════════════════════════════════════════════════════

@test "delete removes profile" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch personal
  run "$OC_PROFILE" delete work
  assert_success
  assert_output --partial "deleted profile 'work'"
  assert_file_not_exist "${PROFILES_DIR}/work.json"
}

@test "delete fails for non-existent profile" {
  run "$OC_PROFILE" delete nonexistent
  assert_failure
  assert_output --partial "does not exist"
}

@test "delete fails for active profile" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" delete work
  assert_failure
  assert_output --partial "cannot delete"
}

@test "delete fails for last profile" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" delete work
  assert_failure
  assert_output --partial "cannot delete the last profile"
}

@test "rm alias works for delete" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch personal
  run "$OC_PROFILE" rm work
  assert_success
}

# ═══════════════════════════════════════════════════════════════
# Profile Rename Tests
# ═══════════════════════════════════════════════════════════════

@test "rename changes profile name" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" rename work renamed
  assert_success
  assert_output --partial "renamed 'work' -> 'renamed'"
  assert_file_exist "${PROFILES_DIR}/renamed.json"
  assert_file_not_exist "${PROFILES_DIR}/work.json"
}

@test "rename updates symlink when active" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" rename work renamed
  run "$OC_PROFILE" which
  assert_output "renamed"
}

@test "rename does not change active when non-active renamed" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch work
  "$OC_PROFILE" rename personal perso
  run "$OC_PROFILE" which
  assert_output "work"
}

@test "rename fails for non-existent profile" {
  run "$OC_PROFILE" rename nonexistent newname
  assert_failure
  assert_output --partial "does not exist"
}

@test "rename fails if target exists" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  run "$OC_PROFILE" rename work personal
  assert_failure
  assert_output --partial "already exists"
}

@test "mv alias works for rename" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" mv work renamed
  assert_success
}

# ═══════════════════════════════════════════════════════════════
# Which Command Tests
# ═══════════════════════════════════════════════════════════════

@test "which shows active profile" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" which
  assert_success
  assert_output "work"
}

@test "which fails when no active profile" {
  rm -f "${AUTH_FILE}"
  run "$OC_PROFILE" which
  assert_failure
  assert_output --partial "no active profile"
}

# ═══════════════════════════════════════════════════════════════
# Security Bug Tests (Should FAIL until bugs are fixed)
# ═══════════════════════════════════════════════════════════════

@test "BUG #1: credential overwrite through symlink" {
  "$OC_PROFILE" make work --current
  local original_token
  original_token=$(grep -o '"access_token":"[^"]*"' "${PROFILES_DIR}/work.json" | cut -d'"' -f4)
  echo '{"access_token":"account-b-token"}' > "${AUTH_FILE}"
  local new_token
  new_token=$(grep -o '"access_token":"[^"]*"' "${PROFILES_DIR}/work.json" | cut -d'"' -f4)
  if [[ "$new_token" == "$original_token" ]]; then
    true  # Bug is fixed
  else
    fail "BUG: Credential overwrite occurred - work.json was modified"
  fi
}

@test "BUG #4: file permissions rely on umask" {
  umask 0022
  "$OC_PROFILE" make work --current
  local perms
  perms=$(file_permissions "${PROFILES_DIR}/work.json")
  if [[ "$perms" == "600" ]]; then
    true  # Bug is fixed
  else
    fail "BUG: File permissions are $perms (should be 600)"
  fi
}

@test "BUG #5: relative symlink not resolved" {
  "$OC_PROFILE" make work --current
  create_relative_symlink "work"
  run "$OC_PROFILE" which
  if [[ "$output" == "work" ]]; then
    true  # Bug is fixed
  else
    fail "BUG: Relative symlink not resolved (got: $output)"
  fi
}

@test "BUG #7: profile count includes unrelated files" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch personal
  echo '{"unrelated": true}' > "${PROFILES_DIR}/unrelated.json"
  run "$OC_PROFILE" delete work
  if [[ "$status" -eq 0 ]]; then
    fail "BUG: Delete succeeded when it should have failed"
  else
    true  # Bug is fixed
  fi
}

# ═══════════════════════════════════════════════════════════════
# Edge Case Tests
# ═══════════════════════════════════════════════════════════════

@test "handles special characters in token" {
  echo '{"access_token":"token-with-dashes_and_underscores"}' > "${AUTH_FILE}"
  run "$OC_PROFILE" make work --current
  assert_success
}

@test "handles empty JSON object" {
  echo '{}' > "${AUTH_FILE}"
  run "$OC_PROFILE" make work --current
  assert_success
}

@test "profile name with hyphens works" {
  run "$OC_PROFILE" make my-work-profile --current
  assert_success
}

@test "profile name with underscores works" {
  run "$OC_PROFILE" make my_work_profile --current
  assert_success
}

@test "profile name with numbers works" {
  run "$OC_PROFILE" make profile123 --current
  assert_success
}
