#!/usr/bin/env bash
# Test helper for oc-profile BATS tests

# OC_PROFILE points to the script under test
export OC_PROFILE="${BATS_TEST_DIRNAME}/../oc-profile"

# Create isolated test environment
setup_test_env() {
  export HOME="${BATS_TEST_TMPDIR}"
  export AUTH_DIR="${HOME}/.local/share/opencode"
  export AUTH_FILE="${AUTH_DIR}/auth.json"
  export PROFILES_DIR="${AUTH_DIR}/profiles"
  
  mkdir -p "${AUTH_DIR}"
  mkdir -p "${PROFILES_DIR}"
  
  # Create default auth.json
  echo '{"access_token":"test-token-a","refresh_token":"test-refresh-a"}' > "${AUTH_FILE}"
}

# Clean up test environment
teardown_test_env() {
  : # BATS handles temp directory cleanup
}

# Create a profile directly (bypassing oc-profile)
create_profile() {
  local name="$1"
  local token="${2:-test-token-$name}"
  echo "{\"access_token\":\"$token\"}" > "${PROFILES_DIR}/${name}.json"
}

# Set active profile by creating symlink
set_active_profile() {
  local name="$1"
  rm -f "${AUTH_FILE}"
  ln -s "${PROFILES_DIR}/${name}.json" "${AUTH_FILE}"
}

# Get file permissions in octal
file_permissions() {
  stat -c "%a" "$1" 2>/dev/null || stat -f "%Lp" "$1"
}

# Create a relative symlink
create_relative_symlink() {
  local name="$1"
  rm -f "${AUTH_FILE}"
  ln -s "profiles/${name}.json" "${AUTH_FILE}"
}

# Simulate OpenCode /connect (overwrites auth.json)
simulate_connect() {
  local token="$1"
  echo "{\"access_token\":\"$token\",\"refresh_token\":\"refresh-$token\"}" > "${AUTH_FILE}"
}
