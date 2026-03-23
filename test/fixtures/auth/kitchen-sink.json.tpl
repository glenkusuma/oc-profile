{
  "__COMMENT__": "Structure-only template. All __SIM_*__ sentinels are replaced at test-setup time with oc_test_<sha256-suffix> strings. See test/test_helper.bash build_multi_provider_auth_json().",

  "openai": {
    "type": "oauth",
    "access": "__SIM_ACCESS_openai__",
    "refresh": "__SIM_REFRESH_openai__",
    "expires": 9999999999000,
    "accountId": "sim-openai-account"
  },

  "anthropic": {
    "type": "oauth",
    "access": "__SIM_ACCESS_anthropic__",
    "refresh": "__SIM_REFRESH_anthropic__",
    "expires": 9999999999000
  },

  "github-copilot": {
    "type": "oauth",
    "access": "__SIM_ACCESS_github-copilot__",
    "refresh": "__SIM_REFRESH_github-copilot__",
    "expires": 9999999999000,
    "enterpriseUrl": "https://github.example.test"
  },

  "amazon-bedrock": {
    "type": "api",
    "key": "__SIM_KEY_amazon-bedrock__"
  },

  "gitlab": {
    "type": "api",
    "key": "__SIM_KEY_gitlab__"
  },

  "nvidia": {
    "type": "api",
    "key": "__SIM_KEY_nvidia__"
  },

  "huggingface": {
    "type": "api",
    "key": "__SIM_KEY_huggingface__"
  },

  "openrouter": {
    "type": "api",
    "key": "__SIM_KEY_openrouter__"
  },

  "mistral": {
    "type": "wellknown",
    "key": "__SIM_KEY_mistral__",
    "token": "__SIM_TOKEN_mistral__"
  }
}
