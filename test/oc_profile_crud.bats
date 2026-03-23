#!/usr/bin/env bats
# Create/update/delete/rename tests for oc-profile

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
# delete / rename
# ──────────────────────────────────────────────────────────────

@test "delete fails for active profile" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  run "$OC_PROFILE" delete personal
  assert_failure
  assert_output --partial "cannot delete the active profile"
}

@test "delete fails for last profile" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" delete work
  assert_failure
  assert_output --partial "cannot delete the last profile"
}

@test "rename updates profile file name" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" rename work renamed
  assert_success
  assert_file_exist "${PROFILES_DIR}/renamed.json"
  assert_file_not_exist "${PROFILES_DIR}/work.json"
}

# ──────────────────────────────────────────────────────────────
# delete
# ──────────────────────────────────────────────────────────────

@test "delete removes profile" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch personal --save-current
  run "$OC_PROFILE" delete work
  assert_success
  assert_output --partial "deleted profile 'work'"
  assert_file_not_exist "${PROFILES_DIR}/work.json"
}

@test "delete fails for non-existent profile" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" delete nonexistent
  assert_failure
  assert_output --partial "does not exist"
}

@test "rm alias works for delete" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch personal --save-current
  run "$OC_PROFILE" rm work
  assert_success
}

# ──────────────────────────────────────────────────────────────
# rename
# ──────────────────────────────────────────────────────────────

@test "rename updates active profile name" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" rename work renamed
  run "$OC_PROFILE" which
  assert_success
  assert_output "renamed"
}

@test "rename does not change active when non-active profile is renamed" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  "$OC_PROFILE" switch work
  "$OC_PROFILE" rename personal perso
  run "$OC_PROFILE" which
  assert_success
  assert_output "work"
}

@test "rename fails for non-existent profile" {
  run "$OC_PROFILE" rename nonexistent newname
  assert_failure
  assert_output --partial "does not exist"
}

@test "rename fails if target name already exists" {
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
