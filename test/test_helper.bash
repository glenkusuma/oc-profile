#!/usr/bin/env bash
# Test helper for oc-profile BATS tests

# OC_PROFILE points to the script under test
export OC_PROFILE="${BATS_TEST_DIRNAME}/../oc-profile"

fixture_auth_openai_oauth() {
  # $1 access
  # $2 refresh
  local access="$1"
  local refresh="$2"
  printf '{"openai":{"type":"oauth","access":"%s","refresh":"%s","expires":1742710800000}}\n' "${access}" "${refresh}"
}

fixture_auth_openai_oauth_1arg() {
  # $1 access; refresh becomes "refresh-$access"
  fixture_auth_openai_oauth "$1" "refresh-$1"
}

# Create isolated test environment (v0.1.0 layout)
setup_test_env() {
  export HOME="${BATS_TEST_TMPDIR}"
  export AUTH_DIR="${HOME}/.local/share/opencode"
  export AUTH_FILE="${AUTH_DIR}/auth.json"
  export PROFILES_DIR="${AUTH_DIR}/profiles"
  export ACTIVE_CREDENTIALS_FILE="${PROFILES_DIR}/auth.active.json"
  export STATE_FILE="${AUTH_DIR}/oc-profile.json"

  mkdir -p "${AUTH_DIR}"
  mkdir -p "${PROFILES_DIR}"

  # Live auth credentials file (OpenCode reads via auth.json symlink).
  fixture_auth_openai_oauth_1arg "test-token-a" > "${ACTIVE_CREDENTIALS_FILE}"
  chmod 600 "${ACTIVE_CREDENTIALS_FILE}" 2>/dev/null || true

  # auth.json must point to profiles/auth.active.json.
  ln -sf "${ACTIVE_CREDENTIALS_FILE}" "${AUTH_FILE}"

  # Empty initial state.
  cat > "${STATE_FILE}" <<'EOF'
{
  "schema_version": 1,
  "cli_version": "0.1.0-rc.1",
  "active_profile": "",
  "profiles": {}
}
EOF
  chmod 600 "${STATE_FILE}" 2>/dev/null || true
}

teardown_test_env() {
  : # BATS handles temp directory cleanup
}

file_permissions() {
  stat -c "%a" "$1" 2>/dev/null || stat -f "%Lp" "$1"
}

# Create a saved profile directly (bypassing oc-profile).
create_saved_profile() {
  # $1 name
  # $2 access (optional)
  local name="$1"
  local access="${2:-test-token-${name}}"
  fixture_auth_openai_oauth_1arg "${access}" > "${PROFILES_DIR}/${name}.json"
  chmod 600 "${PROFILES_DIR}/${name}.json" 2>/dev/null || true
}

# Simulate OpenCode /connect (overwrites live credentials).
simulate_connect() {
  local access="$1"
  fixture_auth_openai_oauth_1arg "${access}" > "${ACTIVE_CREDENTIALS_FILE}"
  chmod 600 "${ACTIVE_CREDENTIALS_FILE}" 2>/dev/null || true
}

setup_legacy_layout() {
  # v0.1.0 legacy layout simulation:
  # - oc-profile.json missing
  # - auth.json symlink points directly to profiles/<name>.json
  local legacy_active="${1:-work}"

  rm -f "${STATE_FILE}" "${ACTIVE_FILE}" 2>/dev/null || true
  rm -f "${AUTH_FILE}" 2>/dev/null || true

  # Ensure legacy saved profile exists.
  create_saved_profile "${legacy_active}" "test-token-legacy-${legacy_active}"

  # Use an absolute symlink to match the "common legacy" case.
  ln -sf "${PROFILES_DIR}/${legacy_active}.json" "${AUTH_FILE}"
}

setup_fresh_layout() {
  # Fresh environment: no valid state file and no legacy symlink marker.
  rm -f "${STATE_FILE}" 2>/dev/null || true
  rm -f "${AUTH_FILE}" 2>/dev/null || true
  rm -f "${ACTIVE_CREDENTIALS_FILE}" 2>/dev/null || true
}

setup_fresh_layout_with_auth_file() {
  # Fresh environment with existing regular auth.json file.
  setup_fresh_layout
  fixture_auth_openai_oauth_1arg "fresh-auth-token" > "${AUTH_FILE}"
  chmod 600 "${AUTH_FILE}" 2>/dev/null || true
}

create_lock_holder() {
  # Holds the oc-profile.lock file using flock for a short time.
  # Used for lock contention tests.
  local lock_file="${AUTH_DIR}/oc-profile.lock"
  (
    exec 9>"${lock_file}"
    flock -n 9
    sleep 2
  ) &
}

# ── Multi-provider fixture helpers ─────────────────────────────────────────────
# All helpers below produce test-only, non-production credentials.
# Convention: every simulated credential string starts with the prefix "oc_test_"
# followed by a SHA-256-derived hex suffix seeded by an arbitrary label so the
# value is reproducible within a test run but obviously synthetic.

# sim_token <label>
#   Echoes "oc_test_<32-hex>" derived from SHA-256 of the label string.
sim_token() {
  local label="${1:-default}"
  printf '%s' "${label}" | sha256sum | awk '{print "oc_test_" substr($1,1,32)}'
}

# build_multi_provider_auth_json [seed_prefix]
#   Emits a complete auth.json-shaped JSON object on stdout.
#   Provider keys: openai, anthropic, github-copilot (oauth);
#                  amazon-bedrock, gitlab, nvidia, huggingface, openrouter (api);
#                  mistral (wellknown).
#   Every credential string starts with "oc_test_" + SHA-256 suffix derived from
#   "<seed_prefix>_<provider>_<field>", making each field unique per seed.
#   seed_prefix defaults to "" (stable per label within a test).
build_multi_provider_auth_json() {
  local seed="${1:-}"
  local -A tok

  for lbl in \
      "openai_access" "openai_refresh" \
      "anthropic_access" "anthropic_refresh" \
      "copilot_access" "copilot_refresh" \
      "bedrock_key" "gitlab_key" \
      "nvidia_key" "huggingface_key" "openrouter_key" \
      "mistral_key" "mistral_token"; do
    tok["${lbl}"]="$(sim_token "${seed}_${lbl}")"
  done

  printf '{'
  printf '"openai":{"type":"oauth","access":"%s","refresh":"%s","expires":9999999999000,"accountId":"sim-openai-account"},' \
    "${tok[openai_access]}" "${tok[openai_refresh]}"
  printf '"anthropic":{"type":"oauth","access":"%s","refresh":"%s","expires":9999999999000},' \
    "${tok[anthropic_access]}" "${tok[anthropic_refresh]}"
  printf '"github-copilot":{"type":"oauth","access":"%s","refresh":"%s","expires":9999999999000,"enterpriseUrl":"https://github.example.test"},' \
    "${tok[copilot_access]}" "${tok[copilot_refresh]}"
  printf '"amazon-bedrock":{"type":"api","key":"%s"},' "${tok[bedrock_key]}"
  printf '"gitlab":{"type":"api","key":"%s"},' "${tok[gitlab_key]}"
  printf '"nvidia":{"type":"api","key":"%s"},' "${tok[nvidia_key]}"
  printf '"huggingface":{"type":"api","key":"%s"},' "${tok[huggingface_key]}"
  printf '"openrouter":{"type":"api","key":"%s"},' "${tok[openrouter_key]}"
  printf '"mistral":{"type":"wellknown","key":"%s","token":"%s"}' \
    "${tok[mistral_key]}" "${tok[mistral_token]}"
  printf '}\n'
}

# write_sim_auth_active [seed_prefix]
#   Writes a multi-provider auth blob to ACTIVE_CREDENTIALS_FILE (mode 600).
write_sim_auth_active() {
  local seed="${1:-}"
  build_multi_provider_auth_json "${seed}" > "${ACTIVE_CREDENTIALS_FILE}"
  chmod 600 "${ACTIVE_CREDENTIALS_FILE}" 2>/dev/null || true
}

# create_saved_profile_multi <name> [seed_prefix]
#   Writes a multi-provider auth blob DIRECTLY to PROFILES_DIR/<name>.json,
#   bypassing the state file. Use this only after the profile is already
#   registered (e.g. to simulate an external edit / hash-mismatch scenario).
create_saved_profile_multi() {
  local name="$1"
  local seed="${2:-${name}}"
  build_multi_provider_auth_json "${seed}" > "${PROFILES_DIR}/${name}.json"
  chmod 600 "${PROFILES_DIR}/${name}.json" 2>/dev/null || true
}

# register_multi_provider_profile <name> [seed_prefix]
#   Writes a multi-provider auth blob to ACTIVE_CREDENTIALS_FILE then calls
#   `oc-profile make <name> --current` so the profile is registered in STATE_FILE.
#   After this call, <name> becomes the active profile.
register_multi_provider_profile() {
  local name="$1"
  local seed="${2:-${name}}"
  build_multi_provider_auth_json "${seed}" > "${ACTIVE_CREDENTIALS_FILE}"
  chmod 600 "${ACTIVE_CREDENTIALS_FILE}" 2>/dev/null || true
  "$OC_PROFILE" make "${name}" --current >/dev/null 2>&1
}
