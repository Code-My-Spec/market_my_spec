#!/bin/bash
# Verify Google OAuth client credentials are configured and Google's OAuth
# endpoints are reachable. Real client_id/secret validation requires a user
# auth flow — see exchange_google_token.sh for that.
#
# Outputs JSON: {"integration":"google_oauth","status":"ok"|"error",...}

set -u

errors=()

if [ -z "${GOOGLE_CLIENT_ID:-}" ]; then
  errors+=("GOOGLE_CLIENT_ID is not set")
fi

if [ -z "${GOOGLE_CLIENT_SECRET:-}" ]; then
  errors+=("GOOGLE_CLIENT_SECRET is not set")
fi

if [ -n "${GOOGLE_CLIENT_ID:-}" ] && ! printf '%s' "$GOOGLE_CLIENT_ID" | grep -q 'apps.googleusercontent.com$'; then
  errors+=("GOOGLE_CLIENT_ID does not end with .apps.googleusercontent.com (suspicious)")
fi

if [ ${#errors[@]} -gt 0 ]; then
  joined=$(printf '%s; ' "${errors[@]}" | sed 's/; $//')
  printf '{"integration":"google_oauth","status":"error","error":"config","details":"%s"}\n' "$joined"
  exit 1
fi

discovery=$(curl -sS -o /dev/null -w "%{http_code}" https://accounts.google.com/.well-known/openid-configuration)
if [ "$discovery" != "200" ]; then
  printf '{"integration":"google_oauth","status":"error","error":"unreachable","details":"Google discovery endpoint returned %s"}\n' "$discovery"
  exit 1
fi

printf '{"integration":"google_oauth","status":"ok","details":"client credentials present; discovery endpoint reachable. Run exchange_google_token.sh to fully validate."}\n'
exit 0
