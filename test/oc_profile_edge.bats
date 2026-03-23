#!/usr/bin/env bats
# Edge-case tests for oc-profile

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
# Edge cases
# ──────────────────────────────────────────────────────────────

@test "handles special characters in token value" {
  simulate_connect "token-with-dashes_and_underscores"
  run "$OC_PROFILE" make work --current
  assert_success
}

@test "handles empty JSON object in live credentials" {
  printf '{}\n' > "${ACTIVE_CREDENTIALS_FILE}"
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
