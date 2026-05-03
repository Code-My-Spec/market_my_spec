#!/bin/bash
# Exchange Google OAuth client credentials for an access token using the
# OAuth 2.0 Device Authorization Grant (RFC 8628). Proves both client_id
# and client_secret work without needing a redirect URI.
#
# Usage: GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... ./exchange_google_token.sh
# Optional: GOOGLE_SCOPES (default: "openid email profile")

set -u

if [ -z "${GOOGLE_CLIENT_ID:-}" ] || [ -z "${GOOGLE_CLIENT_SECRET:-}" ]; then
  printf '{"status":"error","error":"missing_env","details":"GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be set"}\n'
  exit 1
fi

scopes="${GOOGLE_SCOPES:-openid email profile}"

device_resp=$(curl -sS -X POST https://oauth2.googleapis.com/device/code \
  -d "client_id=${GOOGLE_CLIENT_ID}" \
  -d "scope=${scopes}")

device_code=$(printf '%s' "$device_resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("device_code",""))' 2>/dev/null)
user_code=$(printf '%s' "$device_resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("user_code",""))' 2>/dev/null)
verification_url=$(printf '%s' "$device_resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("verification_url",""))' 2>/dev/null)
interval=$(printf '%s' "$device_resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("interval",5))' 2>/dev/null)

if [ -z "$device_code" ]; then
  printf '{"status":"error","error":"device_code_failed","response":%s}\n' "$(printf '%s' "$device_resp" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
  exit 1
fi

printf 'Visit: %s\nEnter code: %s\nPolling every %ss...\n' "$verification_url" "$user_code" "$interval" >&2

while :; do
  sleep "$interval"
  token_resp=$(curl -sS -X POST https://oauth2.googleapis.com/token \
    -d "client_id=${GOOGLE_CLIENT_ID}" \
    -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
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
