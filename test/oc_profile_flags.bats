#!/usr/bin/env bats
# Flag behavior tests for oc-profile

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
# --skip-checks flag
# ──────────────────────────────────────────────────────────────

@test "--skip-checks shows warning banner" {
  run "$OC_PROFILE" --skip-checks list
  assert_success
  assert_output --partial "WARNING: --skip-checks is active"
}

@test "--skip-checks with list works without state" {
  rm -f "${STATE_FILE}"
  run "$OC_PROFILE" --skip-checks list
  assert_success
  assert_output --partial "no profiles saved"
}

@test "OC_PROFILE_SKIP_CHECKS=true enables skip-checks mode" {
  export OC_PROFILE_SKIP_CHECKS=true
  run "$OC_PROFILE" list
  assert_success
  assert_output --partial "WARNING: --skip-checks is active"
}

@test "OC_PROFILE_SKIP_CHECKS env is ignored when --always-checks passed" {
  export OC_PROFILE_SKIP_CHECKS=true
  run "$OC_PROFILE" --always-checks list
  assert_success
  refute_output --partial "WARNING"
}

@test "--skip-checks after command works" {
  run "$OC_PROFILE" list --skip-checks
  assert_success
  assert_output --partial "WARNING: --skip-checks is active"
}

# ──────────────────────────────────────────────────────────────
# --dry-run flag
# ──────────────────────────────────────────────────────────────

@test "--dry-run with make shows planned actions without file creation" {
  "$OC_PROFILE" make baseline --current
  run "$OC_PROFILE" make work --dry-run
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "make 'work'"
  assert_file_not_exist "${PROFILES_DIR}/work.json"
}

@test "--dry-run still enforces first-placeholder guard" {
  run "$OC_PROFILE" make work --dry-run
  assert_failure
  assert_output --partial "first profile must be saved from current credentials"
  assert_file_not_exist "${PROFILES_DIR}/work.json"
}

@test "--dry-run with switch shows planned switch without applying" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  run "$OC_PROFILE" switch work --dry-run
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "switch to 'work'"
  run "$OC_PROFILE" which
  assert_output "personal"
}

@test "--dry-run with delete shows planned deletion without removing" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  run "$OC_PROFILE" delete work --dry-run
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "delete 'work'"
  assert_file_exist "${PROFILES_DIR}/work.json"
}

@test "--dry-run with rename shows planned rename without renaming" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" rename work workplace --dry-run
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "rename 'work' -> 'workplace'"
  assert_file_exist "${PROFILES_DIR}/work.json"
  assert_file_not_exist "${PROFILES_DIR}/workplace.json"
}

@test "--dry-run with migrate shows planned migration without executing" {
  setup_legacy_layout
  run "$OC_PROFILE" migrate --dry-run
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "migrate"
}

@test "--dry-run with init shows planned initialization without executing" {
  setup_fresh_layout_with_auth_file
  run "$OC_PROFILE" init --dry-run
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "init"
  assert_file_exist "${AUTH_FILE}"
  assert_file_not_exist "${STATE_FILE}"
}

@test "--dry-run flag after command works" {
  "$OC_PROFILE" make baseline --current
  run "$OC_PROFILE" make work --dry-run
  assert_success
  assert_output --partial "[DRY-RUN]"
}

# ──────────────────────────────────────────────────────────────
# -v / --verbose flag
# ──────────────────────────────────────────────────────────────

@test "-v shows command progress" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" make personal -v
  assert_success
  assert_output --partial "Creating"
}

@test "-vv shows detailed context" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" make personal -vv
  assert_success
  assert_output --partial "Creating"
}

@test "-v with --dry-run shows verbose dry-run output" {
  "$OC_PROFILE" make baseline --current
  run "$OC_PROFILE" make work --dry-run -v
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "Acquiring lock"
}

@test "-vv with --dry-run shows extra detailed dry-run output" {
  "$OC_PROFILE" make baseline --current
  run "$OC_PROFILE" make work --dry-run -vv
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "Target profile path"
}

# ──────────────────────────────────────────────────────────────
# --dry-run with --skip-checks
# ──────────────────────────────────────────────────────────────

@test "--dry-run --skip-checks shows both warnings" {
  "$OC_PROFILE" make baseline --current
  run "$OC_PROFILE" make work --dry-run --skip-checks
  assert_success
  assert_output --partial "WARNING: --skip-checks is active"
  assert_output --partial "[DRY-RUN]"
}

@test "--skip-checks --dry-run order doesn't matter" {
  "$OC_PROFILE" make baseline --current
  run "$OC_PROFILE" make work --skip-checks --dry-run
  assert_success
  assert_output --partial "WARNING: --skip-checks is active"
  assert_output --partial "[DRY-RUN]"
}

# ──────────────────────────────────────────────────────────────
# Flag combinations with version/help
# ──────────────────────────────────────────────────────────────

@test "--skip-checks --version works without error" {
  run "$OC_PROFILE" --skip-checks --version
  assert_success
  assert_output "0.1.0-rc.1"
}

@test "--dry-run --version shows version without dry-run message" {
  run "$OC_PROFILE" --dry-run --version
  assert_success
  assert_output "0.1.0-rc.1"
  refute_output --partial "[DRY-RUN]"
}

@test "--skip-checks help works" {
  run "$OC_PROFILE" --skip-checks help
  assert_success
  assert_output --partial "OPTIONS"
}

@test "help includes init command" {
  run "$OC_PROFILE" help
  assert_success
  assert_output --partial "init"
}

@test "--verbose help works" {
  run "$OC_PROFILE" -v help
  assert_success
  assert_output --partial "OPTIONS"
}

@test "-vv help works" {
  run "$OC_PROFILE" -vv help
  assert_success
  assert_output --partial "OPTIONS"
}

# ──────────────────────────────────────────────────────────────
# Multiple verbose flags
# ──────────────────────────────────────────────────────────────

@test "multiple -v flags accumulate" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" make personal -v -v
  assert_success
  assert_output --partial "Creating"
}

@test "-vvv works" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" make personal -vvv
  assert_success
  assert_output --partial "Creating"
}

@test "-vvvv works" {
  "$OC_PROFILE" make work --current
  run "$OC_PROFILE" make personal -vvvv
  assert_success
  assert_output --partial "Creating"
}

# ──────────────────────────────────────────────────────────────
# Edge cases
# ──────────────────────────────────────────────────────────────

@test "unknown global flag shows error" {
  run "$OC_PROFILE" --unknown-flag list
  assert_failure
  assert_output --partial "unknown flag"
}

@test "--always-checks default shows no warning" {
  run "$OC_PROFILE" list
  assert_success
  refute_output --partial "WARNING"
}

@test "version flag with -v" {
  run "$OC_PROFILE" -v --version
  assert_success
  assert_output "0.1.0-rc.1"
}

@test "help with -vv" {
  run "$OC_PROFILE" -vv help
  assert_success
  assert_output --partial "USAGE"
}

@test "--dry-run with -v shows verbose output" {
  "$OC_PROFILE" make baseline --current
  run "$OC_PROFILE" make work --dry-run -v
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "Acquiring lock"
}

@test "-v with switch shows verbose output" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current
  run "$OC_PROFILE" switch work -v
  assert_success
  assert_output --partial "Switching to"
}
