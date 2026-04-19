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

make_fake_jq_proxy() {
  local version="$1"
  local real_jq
  real_jq="$(command -v jq)"
  local path="${BATS_TEST_TMPDIR}/fake-jq-${version}"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'if [[ "${1:-}" == "--version" ]]; then'
    printf '  echo "jq-%s"\n' "${version}"
    printf '%s\n' '  exit 0'
    printf '%s\n' 'fi'
    printf 'exec "%s" "$@"\n' "${real_jq}"
  } > "${path}"
  chmod +x "${path}"
  echo "${path}"
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

@test "strict mode enforces jq >= 1.8 with exit code 13" {
  local fake
  fake="$(make_fake_jq_proxy "1.7")"
  export OC_PROFILE_JQ="${fake}"

  run "$OC_PROFILE" make work --current
  assert_failure
  assert [ "$status" -eq 13 ]
  assert_output --partial "jq >= 1.8 is required"
  assert_output --partial "Install"
}

@test "--always-checks enforces strict mode even when env enables skip-checks" {
  local fake
  fake="$(make_fake_jq_proxy "1.7")"
  export OC_PROFILE_JQ="${fake}"
  export OC_PROFILE_SKIP_CHECKS=true

  run "$OC_PROFILE" --always-checks make work --current
  assert_failure
  assert [ "$status" -eq 13 ]
  assert_output --partial "jq >= 1.8 is required"
  refute_output --partial "WARNING: --skip-checks is active"
}

@test "strict mode accepts jq 1.8" {
  local fake
  fake="$(make_fake_jq_proxy "1.8")"
  export OC_PROFILE_JQ="${fake}"

  run "$OC_PROFILE" make work --current
  assert_success
}

@test "--skip-checks bypasses jq version floor when required capabilities are available" {
  local fake
  fake="$(make_fake_jq_proxy "1.7")"
  export OC_PROFILE_JQ="${fake}"

  run "$OC_PROFILE" --skip-checks make work --current
  assert_success
  assert_output --partial "WARNING: --skip-checks is active"
}

@test "both flags use strict mode even when --skip-checks appears first" {
  local fake
  fake="$(make_fake_jq_proxy "1.7")"
  export OC_PROFILE_JQ="${fake}"

  run "$OC_PROFILE" --skip-checks --always-checks make work --current
  assert_failure
  assert [ "$status" -eq 13 ]
  assert_output --partial "jq >= 1.8 is required"
}

@test "both flags use strict mode even when --skip-checks appears last" {
  local fake
  fake="$(make_fake_jq_proxy "1.7")"
  export OC_PROFILE_JQ="${fake}"

  run "$OC_PROFILE" --always-checks --skip-checks make work --current
  assert_failure
  assert [ "$status" -eq 13 ]
  assert_output --partial "jq >= 1.8 is required"
}

@test "strict mode accepts jq 1.8 dirty suffix" {
  local fake
  fake="$(make_fake_jq_proxy "1.8.1-dirty")"
  export OC_PROFILE_JQ="${fake}"

  run "$OC_PROFILE" make work --current
  assert_success
}

@test "strict mode accepts jq 1.8 git describe suffix" {
  local fake
  fake="$(make_fake_jq_proxy "1.8.1-23-gcff4e00")"
  export OC_PROFILE_JQ="${fake}"

  run "$OC_PROFILE" make work --current
  assert_success
}

@test "strict mode accepts jq 1.8 git describe dirty suffix" {
  local fake
  fake="$(make_fake_jq_proxy "1.8.1-23-gcff4e00-dirty")"
  export OC_PROFILE_JQ="${fake}"

  run "$OC_PROFILE" make work --current
  assert_success
}

@test "strict mode rejects jq 1.7 dirty suffix with exit code 13" {
  local fake
  fake="$(make_fake_jq_proxy "1.7.1-dirty")"
  export OC_PROFILE_JQ="${fake}"

  run "$OC_PROFILE" make work --current
  assert_failure
  assert [ "$status" -eq 13 ]
  assert_output --partial "jq >= 1.8 is required"
  assert_output --partial "found jq-1.7.1-dirty"
}

@test "strict mode rejects non-numeric jq git fallback as unrecognized" {
  local fake
  fake="$(make_fake_jq_proxy "master-4467af7-dirty")"
  export OC_PROFILE_JQ="${fake}"

  run "$OC_PROFILE" make work --current
  assert_failure
  assert [ "$status" -eq 13 ]
  assert_output --partial "version output was unrecognized"
}

@test "skip mode missing jq fails with exit 15 on list" {
  export OC_PROFILE_JQ="/tmp/does-not-exist-jq"

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --skip-checks list
  assert_failure
  assert [ "$status" -eq 15 ]
  assert_output --partial "operation 'list' requires jq in --skip-checks mode; rerun without --skip-checks (or pass --always-checks)."
}

@test "skip mode missing flock fails with exit 15 on make" {
  local real_jq
  real_jq="$(command -v jq)"
  export OC_PROFILE_JQ="${real_jq}"

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --skip-checks make work --current
  assert_failure
  assert [ "$status" -eq 15 ]
  assert_output --partial "operation 'make' requires flock in --skip-checks mode; rerun without --skip-checks (or pass --always-checks)."
}

@test "skip mode missing jq and flock fails with combined exit 15 message" {
  export OC_PROFILE_JQ="/tmp/does-not-exist-jq"

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --skip-checks make work --current
  assert_failure
  assert [ "$status" -eq 15 ]
  assert_output --partial "operation 'make' requires jq and flock in --skip-checks mode; rerun without --skip-checks (or pass --always-checks)."
}

@test "skip mode alias ls enforces canonical list jq capability message" {
  export OC_PROFILE_JQ="/tmp/does-not-exist-jq"

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --skip-checks ls
  assert_failure
  assert [ "$status" -eq 15 ]
  assert_output --partial "operation 'list' requires jq in --skip-checks mode; rerun without --skip-checks (or pass --always-checks)."
}

@test "skip mode alias rm enforces canonical delete combined capability message" {
  export OC_PROFILE_JQ="/tmp/does-not-exist-jq"

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --skip-checks rm work
  assert_failure
  assert [ "$status" -eq 15 ]
  assert_output --partial "operation 'delete' requires jq and flock in --skip-checks mode; rerun without --skip-checks (or pass --always-checks)."
}

@test "skip mode init enforces combined jq and flock capability message" {
  export OC_PROFILE_JQ="/tmp/does-not-exist-jq"

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --skip-checks init
  assert_failure
  assert [ "$status" -eq 15 ]
  assert_output --partial "operation 'init' requires jq and flock in --skip-checks mode; rerun without --skip-checks (or pass --always-checks)."
}

@test "skip mode delete command enforces canonical combined capability message" {
  export OC_PROFILE_JQ="/tmp/does-not-exist-jq"

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --skip-checks delete work
  assert_failure
  assert [ "$status" -eq 15 ]
  assert_output --partial "operation 'delete' requires jq and flock in --skip-checks mode; rerun without --skip-checks (or pass --always-checks)."
}

@test "skip mode list --skip-checks tail placement enforces jq capability gate under minimal PATH" {
  export OC_PROFILE_JQ="/tmp/does-not-exist-jq"

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" list --skip-checks
  assert_failure
  assert [ "$status" -eq 15 ]
  assert_output --partial "operation 'list' requires jq in --skip-checks mode; rerun without --skip-checks (or pass --always-checks)."
}

@test "list details alias parity holds between ls -a and list -a" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current

  run "$OC_PROFILE" ls -a
  assert_success
  local out_ls="$output"

  run "$OC_PROFILE" list -a
  assert_success
  local out_list="$output"

  assert [ "$out_ls" = "$out_list" ]
  assert_output --partial "hash="
  assert_output --partial "providers="
}

@test "help alias topics route to canonical command usage" {
  run "$OC_PROFILE" help ls
  assert_success
  assert_output --partial "usage: oc-profile list [--details|--detail|-a]"

  run "$OC_PROFILE" help rm
  assert_success
  assert_output --partial "usage: oc-profile delete <name>"

  run "$OC_PROFILE" help mv
  assert_success
  assert_output --partial "usage: oc-profile rename <old> <new>"
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

@test "--skip-checks --version remains exempt when jq and flock are unavailable" {
  export OC_PROFILE_JQ="/tmp/does-not-exist-jq"
  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --skip-checks --version
  assert_success
  assert_output "0.1.0-rc.1"
}

@test "minimal-PATH version precedence works when --skip-checks appears first" {
  local expected_version
  export OC_PROFILE_JQ="/tmp/does-not-exist-jq"

  run "$OC_PROFILE" --version
  assert_success
  expected_version="$output"

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --skip-checks --always-checks --version
  assert_success
  assert_output "$expected_version"
  refute_output --partial "WARNING: --skip-checks is active"
}

@test "minimal-PATH version precedence works when --always-checks appears first" {
  local expected_version
  export OC_PROFILE_JQ="/tmp/does-not-exist-jq"

  run "$OC_PROFILE" --version
  assert_success
  expected_version="$output"

  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --always-checks --skip-checks --version
  assert_success
  assert_output "$expected_version"
  refute_output --partial "WARNING: --skip-checks is active"
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

@test "--skip-checks help remains exempt when jq and flock are unavailable" {
  export OC_PROFILE_JQ="/tmp/does-not-exist-jq"
  run_with_minimal_path "$(empty_bin_path)" /usr/bin/bash "$OC_PROFILE" --skip-checks help
  assert_success
  assert_output --partial "USAGE"
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

@test "--verbose help make works" {
  run "$OC_PROFILE" -v help make
  assert_success
  assert_output --partial "usage: oc-profile make <name> [--current]"
}

@test "-vv help works" {
  run "$OC_PROFILE" -vv help
  assert_success
  assert_output --partial "OPTIONS"
}

@test "--skip-checks help make works" {
  run "$OC_PROFILE" --skip-checks help make
  assert_success
  assert_output --partial "usage: oc-profile make <name> [--current]"
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

@test "grouped short flags route global -v and list-local -a correctly" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current

  run "$OC_PROFILE" -av list
  assert_success
  assert_output --partial "hash="
  assert_output --partial "providers="
}

@test "grouped short flags -ah and -ha fail without command ownership" {
  run "$OC_PROFILE" -ah
  assert_failure
  assert [ "$status" -eq 1 ]
  assert_output --partial "unknown flag '-a'"

  run "$OC_PROFILE" -ha
  assert_failure
  assert [ "$status" -eq 1 ]
  assert_output --partial "unknown flag '-a'"
}

@test "list details aliases --details --detail -a are equivalent" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current

  run "$OC_PROFILE" list --details
  assert_success
  local out_details="$output"

  run "$OC_PROFILE" list --detail
  assert_success
  local out_detail="$output"

  run "$OC_PROFILE" list -a
  assert_success
  local out_short="$output"

  assert [ "$out_details" = "$out_detail" ]
  assert [ "$out_details" = "$out_short" ]
}

@test "grouped short flags -va and -av are equivalent for list" {
  "$OC_PROFILE" make work --current
  "$OC_PROFILE" make personal --current

  run "$OC_PROFILE" -av list
  assert_success
  local out_av="$output"

  run "$OC_PROFILE" -va list
  assert_success
  local out_va="$output"

  assert [ "$out_av" = "$out_va" ]
}

@test "command-local long flags are accepted before command token" {
  "$OC_PROFILE" make base --current

  run "$OC_PROFILE" --current make beforemake
  assert_success
  assert_output --partial "created profile 'beforemake'"

  simulate_connect "test-token-save-before"
  run "$OC_PROFILE" --set-active save base
  assert_success
  assert_output --partial "set as active"

  "$OC_PROFILE" make empty
  run "$OC_PROFILE" --allow-empty-target --no-save-current switch empty
  assert_success
  assert_output --partial "switched to 'empty'"

  run "$OC_PROFILE" --details list
  assert_success
  assert_output --partial "hash="
}

@test "list details marks invalid JSON profile and avoids token leakage" {
  "$OC_PROFILE" make work --current
  simulate_connect "test-token-sensitive"
  "$OC_PROFILE" save work
  printf '%s\n' '{invalid-json' > "${PROFILES_DIR}/work.json"

  run "$OC_PROFILE" list --details
  assert_success
  assert_output --partial "hash=<invalid>"
  assert_output --partial "providers=<invalid-json>"
  refute_output --partial "test-token-sensitive"
}
