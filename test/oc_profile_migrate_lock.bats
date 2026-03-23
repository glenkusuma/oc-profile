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

@test "lock contention returns exit code 14" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current

  create_lock_holder

  run "$OC_PROFILE" switch work
  assert_failure
  assert [ "$status" -eq 14 ]
}
