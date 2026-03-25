#!/usr/bin/env bats
# Security regression tests for oc-profile

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
# Security bug regressions for current layout behavior
# ──────────────────────────────────────────────────────────────

@test "writing to live credentials does not overwrite saved profile" {
  "$OC_PROFILE" make work --current
  local before
  before="$(cat "${PROFILES_DIR}/work.json")"

  # Simulate OpenCode refreshing the live credentials file.
  simulate_connect "account-b-token"

  local after
  after="$(cat "${PROFILES_DIR}/work.json")"
  assert [ "${before}" = "${after}" ]
}

@test "profile files are created mode 600 regardless of umask" {
  umask 0022
  "$OC_PROFILE" make work --current
  local perms
  perms="$(file_permissions "${PROFILES_DIR}/work.json")"
  assert [ "${perms}" = "600" ]
}

@test "migrate handles relative symlink pointing to legacy profile file" {
  # Build a legacy layout where auth.json uses a relative path.
  rm -f "${STATE_FILE}" "${AUTH_FILE}" 2>/dev/null || true
  create_saved_profile "work" "test-token-legacy"
  # Relative symlink: auth.json -> profiles/work.json
  (cd "${AUTH_DIR}" && ln -sf "profiles/work.json" auth.json)

  run "$OC_PROFILE" migrate
  assert_success
  assert_file_exist "${STATE_FILE}"
}

@test "delete rejects when unrelated JSON file exists in profiles dir" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch personal --save-current

  # Drop an unrecognized JSON file directly into the profiles directory.
  echo '{"unrelated": true}' > "${PROFILES_DIR}/unrelated.json"

  run "$OC_PROFILE" delete work
  assert_failure
  assert_output --partial "unrecognized"
}
