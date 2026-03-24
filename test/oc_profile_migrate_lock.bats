#!/usr/bin/env bats
# Migration and locking tests for oc-profile

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
# migrate + legacy gating + locking
# ──────────────────────────────────────────────────────────────

@test "mutating commands refuse legacy layout with exit code 10" {
  setup_legacy_layout "work"
  rm -f "${STATE_FILE}" 2>/dev/null || true

  run "$OC_PROFILE" make work --current
  assert_failure
  assert [ "$status" -eq 10 ]
  assert_output --partial "legacy layout detected"
}

@test "mutating commands refuse fresh layout with exit code 16" {
  setup_fresh_layout

  run "$OC_PROFILE" make work --current
  assert_failure
  assert [ "$status" -eq 16 ]
  assert_output --partial "fresh environment detected"
  assert_output --partial "run 'oc-profile init'"
}

@test "migrate refuses fresh layout and points to init" {
  setup_fresh_layout

  run "$OC_PROFILE" migrate
  assert_failure
  assert [ "$status" -eq 16 ]
  assert_output --partial "fresh environment detected"
  assert_output --partial "run 'oc-profile init'"
}

@test "migrate creates oc-profile.json and repoints auth.json to profiles/auth.active.json" {
  setup_legacy_layout "work"

  run "$OC_PROFILE" migrate
  assert_success

  assert_file_exist "${STATE_FILE}"
  assert_file_exist "${ACTIVE_CREDENTIALS_FILE}"
  assert [ -L "${AUTH_FILE}" ]
  # auth.json should now point to the active file.
  readlink "${AUTH_FILE}" | grep -q "profiles/auth.active.json"
}

@test "first placeholder attempt is blocked and does not alter live credentials" {
  local before
  before="$(sha256sum "${ACTIVE_CREDENTIALS_FILE}" | awk '{print $1}')"

  run "$OC_PROFILE" make work
  assert_failure
  assert_output --partial "first profile must be saved from current credentials"
  assert_file_not_exist "${PROFILES_DIR}/work.json"

  local after
  after="$(sha256sum "${ACTIVE_CREDENTIALS_FILE}" | awk '{print $1}')"
  assert [ "${before}" = "${after}" ]
}

@test "lock contention returns exit code 14" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current

  create_lock_holder

  run "$OC_PROFILE" switch work
  assert_failure
  assert [ "$status" -eq 14 ]
}
