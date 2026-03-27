#!/usr/bin/env bats
# Switch behavior tests for oc-profile

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
# switch
# ──────────────────────────────────────────────────────────────

@test "switch changes active profile" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  run "$OC_PROFILE" switch work
  assert_success
  assert_output --partial "switched to 'work'"
  run "$OC_PROFILE" which
  assert_success
  assert_output "work"
}

@test "switch reports when already on profile" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" switch work
  assert_success
  assert_output --partial "already on profile 'work'"
}

@test "switch fails for non-existent profile" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" switch nonexistent
  assert_failure
  assert_output --partial "does not exist"
}

@test "switch dirty-active non-interactive exits 11 and does not leak tokens" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch work

  # Make live auth different from saved active profile.
  simulate_connect "test-token-dirty"

  run "$OC_PROFILE" switch personal
  assert_failure
  assert [ "$status" -eq 11 ]
  assert_output --partial "prompt required to handle dirty active credentials"
  # Ensure we never print credential values.
  refute_output --partial "test-token-dirty"
}

@test "switch hash-mismatch non-interactive exits 12 without trust flag" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch work

  # Modify saved target profile on disk without updating state hash.
  create_saved_profile "personal" "test-token-hash-mismatch"

  run "$OC_PROFILE" switch personal
  assert_failure
  assert [ "$status" -eq 12 ]
  assert_output --partial "hash mismatch refused"
}

@test "switch dirty-active with save-current still exits 12 on target hash mismatch" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch work

  # Make active credentials dirty so save-current branch runs.
  simulate_connect "test-token-dirty-save-path"

  # Tamper the target profile without updating state hash.
  create_saved_profile "personal" "test-token-hash-mismatch-dirty"

  run "$OC_PROFILE" switch personal --save-current
  assert_failure
  assert [ "$status" -eq 12 ]
  assert_output --partial "hash mismatch refused"
}

@test "switch hash-mismatch proceeds with --trust-mismatch" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch work

  create_saved_profile "personal" "test-token-hash-mismatch"

  run "$OC_PROFILE" switch personal --trust-mismatch
  assert_success
  assert_output --partial "switched to 'personal'"
}

@test "switch to empty target fails non-interactive without --allow-empty-target" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make empty

  run "$OC_PROFILE" switch empty --no-save-current
  assert_failure
  assert [ "$status" -eq 11 ]
  assert_output --partial "prompt required"
  assert_output --partial "--allow-empty-target"
}

@test "switch to empty target succeeds with --allow-empty-target" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make empty

  run "$OC_PROFILE" switch empty --allow-empty-target --no-save-current
  assert_success
  assert_output --partial "switched to 'empty'"
}

@test "empty-target safeguard wins precedence over hash mismatch" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make empty
  jq '.profiles.empty.sha256 = "deadbeef"' "${STATE_FILE}" > "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "${STATE_FILE}"

  run "$OC_PROFILE" switch empty --no-save-current
  assert_failure
  assert [ "$status" -eq 11 ]
  assert_output --partial "--allow-empty-target"
}

@test "with allow-empty-target hash mismatch gate still applies" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make empty
  create_saved_profile "empty" "tamper-empty"

  run "$OC_PROFILE" switch empty --allow-empty-target --no-save-current
  assert_failure
  assert [ "$status" -eq 12 ]
  assert_output --partial "hash mismatch refused"
}

# ──────────────────────────────────────────────────────────────
# switch behavior details
# ──────────────────────────────────────────────────────────────

@test "switch keeps auth.json pointing to auth.active.json after switch" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch work
  # auth.json must still be a symlink to ACTIVE_CREDENTIALS_FILE, not a regular file.
  assert [ -L "${AUTH_FILE}" ]
  local target
  target="$(readlink "${AUTH_FILE}")"
  assert [ "${target}" = "${ACTIVE_CREDENTIALS_FILE}" ]
}
