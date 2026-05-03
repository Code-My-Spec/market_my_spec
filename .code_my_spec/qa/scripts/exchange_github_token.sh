#!/bin/bash
# Exchange GitHub OAuth App client credentials for an access token using
# GitHub's Device Authorization Grant. Proves both client_id and client_secret
# work without needing a redirect URI.
#
# Usage: GITHUB_CLIENT_ID=... GITHUB_CLIENT_SECRET=... ./exchange_github_token.sh
# Optional: GITHUB_SCOPES (default: "read:user user:email")
#
# Note: GitHub's OAuth App device flow must be enabled in the OAuth App's
# settings page (Device flow checkbox). Without it, the code endpoint returns
# device_flow_disabled.

set -u

if [ -z "${GITHUB_CLIENT_ID:-}" ] || [ -z "${GITHUB_CLIENT_SECRET:-}" ]; then
  printf '{"status":"error","error":"missing_env","details":"GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET must be set"}\n'
  exit 1
fi

scopes="${GITHUB_SCOPES:-read:user user:email}"

device_resp=$(curl -sS -X POST https://github.com/login/device/code \
  -H "Accept: application/json" \
  -d "client_id=${GITHUB_CLIENT_ID}" \
  -d "scope=${scopes}")

err=$(printf '%s' "$device_resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("error",""))' 2>/dev/null)
if [ -n "$err" ]; then
  printf '{"status":"error","error":"%s","response":%s,"hint":"Enable Device flow in OAuth App settings if error is device_flow_disabled"}\n' "$err" "$(printf '%s' "$device_resp" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
  exit 1
fi

device_code=$(printf '%s' "$device_resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("device_code",""))')
user_code=$(printf '%s' "$device_resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("user_code",""))')
verification_uri=$(printf '%s' "$device_resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("verification_uri",""))')
interval=$(printf '%s' "$device_resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("interval",5))')

if [ -z "$device_code" ]; then
  printf '{"status":"error","error":"device_code_missing","response":%s}\n' "$(printf '%s' "$device_resp" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
  exit 1
fi

printf 'Visit: %s\nEnter code: %s\nPolling every %ss...\n' "$verification_uri" "$user_code" "$interval" >&2

while :; do
  sleep "$interval"
  token_resp=$(curl -sS -X POST https://github.com/login/oauth/access_token \
    -H "Accept: application/json" \
    -d "client_id=${GITHUB_CLIENT_ID}" \
    -d "client_secret=${GITHUB_CLIENT_SECRET}" \
    -d "device_code=${device_code}" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:device_code")
  err=$(printf '%s' "$token_resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("error",""))' 2>/dev/null)
  case "$err" in
    "")
      access_token=$(printf '%s' "$token_resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token",""))')
      if [ -n "$access_token" ]; then
        printf '{"status":"ok","details":"device flow completed; access_token issued","access_token_present":true}\n'
        exit 0
      fi
      printf '{"status":"error","error":"unknown","response":%s}\n' "$(printf '%s' "$token_resp" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
      exit 1
      ;;
    "authorization_pending"|"slow_down")
      continue
      ;;
    *)
      printf '{"status":"error","error":"%s","response":%s}\n' "$err" "$(printf '%s' "$token_resp" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
      exit 1
      ;;
  esac
done
