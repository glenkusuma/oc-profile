#!/usr/bin/env bats
# Multi-provider auth fixture tests for oc-profile

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

# ── Multi-provider auth fixture tests ─────────────────────────────────────────
# Credentials use "oc_test_" prefix + SHA-256 suffix (see sim_token in
# test_helper.bash). Assertions check prefix only; full values are opaque.

@test "multi-provider: sim_token produces oc_test_ prefix" {
  result="$(sim_token "sanity")"
  [[ "${result}" == oc_test_* ]]
}

@test "multi-provider: build_multi_provider_auth_json emits valid JSON" {
  local json
  json="$(build_multi_provider_auth_json "t1")"
  echo "${json}" | jq . >/dev/null
}

@test "multi-provider: build_multi_provider_auth_json has all expected provider keys" {
  local json
  json="$(build_multi_provider_auth_json "t2")"
  local keys
  keys="$(echo "${json}" | jq -r 'keys[]' | sort | tr '\n' ',')"
  [[ "${keys}" == *"openai"* ]]
  [[ "${keys}" == *"anthropic"* ]]
  [[ "${keys}" == *"github-copilot"* ]]
  [[ "${keys}" == *"amazon-bedrock"* ]]
  [[ "${keys}" == *"gitlab"* ]]
  [[ "${keys}" == *"nvidia"* ]]
  [[ "${keys}" == *"huggingface"* ]]
  [[ "${keys}" == *"openrouter"* ]]
  [[ "${keys}" == *"mistral"* ]]
}

@test "multi-provider: all credential strings use oc_test_ prefix" {
  local json
  json="$(build_multi_provider_auth_json "t3")"
  # Collect every string value that should be a simulated credential
  while IFS= read -r val; do
    [[ "${val}" == oc_test_* ]] || {
      echo "FAIL: unexpected credential value: ${val}" >&2
      return 1
    }
  done < <(echo "${json}" | jq -r '
    .. | objects |
    (.access?, .refresh?, .key?, .token?) // empty
  ' | grep -v '^$')
}

@test "multi-provider: oauth provider has required fields" {
  local json
  json="$(build_multi_provider_auth_json "t4")"
  local type access refresh expires
  type="$(echo "${json}"    | jq -r '.openai.type')"
  access="$(echo "${json}"  | jq -r '.openai.access')"
  refresh="$(echo "${json}" | jq -r '.openai.refresh')"
  expires="$(echo "${json}" | jq -r '.openai.expires')"
  [[ "${type}"    == "oauth"   ]]
  [[ "${access}"  == oc_test_* ]]
  [[ "${refresh}" == oc_test_* ]]
  [[ "${expires}" -gt 0        ]]
}

@test "multi-provider: api provider has required fields" {
  local json
  json="$(build_multi_provider_auth_json "t5")"
  local type key
  type="$(echo "${json}" | jq -r '."amazon-bedrock".type')"
  key="$(echo "${json}"  | jq -r '."amazon-bedrock".key')"
  [[ "${type}" == "api"    ]]
  [[ "${key}"  == oc_test_* ]]
}

@test "multi-provider: wellknown provider has key and token" {
  local json
  json="$(build_multi_provider_auth_json "t6")"
  local type key token
  type="$(echo "${json}"  | jq -r '.mistral.type')"
  key="$(echo "${json}"   | jq -r '.mistral.key')"
  token="$(echo "${json}" | jq -r '.mistral.token')"
  [[ "${type}"  == "wellknown" ]]
  [[ "${key}"   == oc_test_*   ]]
  [[ "${token}" == oc_test_*   ]]
}

@test "multi-provider: two different seeds produce different credential values" {
  local j1 j2
  j1="$(build_multi_provider_auth_json "seedA")"
  j2="$(build_multi_provider_auth_json "seedB")"
  local a1 a2
  a1="$(echo "${j1}" | jq -r '.openai.access')"
  a2="$(echo "${j2}" | jq -r '.openai.access')"
  [[ "${a1}" != "${a2}" ]]
}

@test "multi-provider: make profile from multi-provider active credentials" {
  write_sim_auth_active "mp_make"
  run "$OC_PROFILE" make mp-work --current
  assert_success
  [[ -f "${PROFILES_DIR}/mp-work.json" ]]
  # The saved profile must contain every provider key
  for key in openai anthropic github-copilot amazon-bedrock gitlab nvidia huggingface openrouter mistral; do
    jq -e --arg k "${key}" '.[$k]' "${PROFILES_DIR}/mp-work.json" >/dev/null
  done
}

@test "multi-provider: saved profile retains oc_test_ prefixed credentials" {
  write_sim_auth_active "mp_retain"
  run "$OC_PROFILE" make mp-retain --current
  assert_success
  local saved_access
  saved_access="$(jq -r '.openai.access' "${PROFILES_DIR}/mp-retain.json")"
  [[ "${saved_access}" == oc_test_* ]]
}

@test "multi-provider: switch between two multi-provider profiles" {
  register_multi_provider_profile "mp-alpha" "alpha"
  register_multi_provider_profile "mp-beta"  "beta"

  run "$OC_PROFILE" switch mp-alpha --no-save-current
  assert_success
  local alpha_access beta_access
  alpha_access="$(jq -r '.openai.access' "${ACTIVE_CREDENTIALS_FILE}")"
  [[ "${alpha_access}" == oc_test_* ]]

  run "$OC_PROFILE" switch mp-beta --no-save-current
  assert_success
  beta_access="$(jq -r '.openai.access' "${ACTIVE_CREDENTIALS_FILE}")"
  [[ "${beta_access}" == oc_test_* ]]
  [[ "${alpha_access}" != "${beta_access}" ]]
}

@test "multi-provider: auth.json remains a symlink after multi-provider switch" {
  register_multi_provider_profile "mp-link" "link"
  run "$OC_PROFILE" switch mp-link --no-save-current
  assert_success
  [[ -L "${AUTH_DIR}/auth.json" ]]
}

@test "multi-provider: dirty-active detected when multi-provider blob changes" {
  # Create two profiles so switching does not short-circuit on "already on profile".
  register_multi_provider_profile "mp-dirty-a" "dirty_seed_a"
  register_multi_provider_profile "mp-dirty-b" "dirty_seed_b"
  run "$OC_PROFILE" switch mp-dirty-a --no-save-current
  assert_success

  # Tamper with one credential in the live file
  local patched
  patched="$(jq '.openai.access = "oc_test_tampered_value_12345678901234"' "${ACTIVE_CREDENTIALS_FILE}")"
  echo "${patched}" > "${ACTIVE_CREDENTIALS_FILE}"

  # In non-interactive mode without save/no-save decision, dirty-active must fail with E_PROMPT_NONINT.
  run "$OC_PROFILE" switch mp-dirty-b
  assert_failure
  assert [ "$status" -eq 11 ]
  assert_output --partial "prompt required to handle dirty active credentials"
}

@test "multi-provider: hash mismatch triggers trust-mismatch requirement" {
  # Create two profiles so switching to the target exercises hash verification path.
  register_multi_provider_profile "mp-hash-a" "hash_seed_a"
  register_multi_provider_profile "mp-hash-b" "hash_seed_b"
  run "$OC_PROFILE" switch mp-hash-a --no-save-current
  assert_success

  # Overwrite the target saved profile with different credentials (simulating external edit).
  # Use create_saved_profile_multi (direct write) to bypass state, producing a hash mismatch.
  create_saved_profile_multi "mp-hash-b" "hash_seed_b_MODIFIED"

  # Switching without --trust-mismatch in non-interactive mode must fail with E_HASH_MISMATCH.
  run "$OC_PROFILE" switch mp-hash-b --no-save-current
  assert_failure
  assert [ "$status" -eq 12 ]
  assert_output --partial "hash mismatch refused"
}

@test "multi-provider: which shows correct profile after multi-provider switch" {
  register_multi_provider_profile "mp-which" "which_seed"
  run "$OC_PROFILE" switch mp-which --no-save-current
  assert_success
  run "$OC_PROFILE" which
  assert_success
  assert_output "mp-which"
}

@test "multi-provider: list shows multiple multi-provider profiles" {
  for name in mp-list-a mp-list-b mp-list-c mp-list-d mp-list-e; do
    register_multi_provider_profile "${name}" "${name}"
  done
  run "$OC_PROFILE" list
  assert_success
  for name in mp-list-a mp-list-b mp-list-c mp-list-d mp-list-e; do
    assert_output --partial "${name}"
  done
}

@test "multi-provider: state rebuild is consistent with 5 multi-provider profiles" {
  for i in 1 2 3 4 5; do
    register_multi_provider_profile "mp-stress-${i}" "stress_${i}"
  done
  run "$OC_PROFILE" list
  assert_success
  for i in 1 2 3 4 5; do
    assert_output --partial "mp-stress-${i}"
  done
}
