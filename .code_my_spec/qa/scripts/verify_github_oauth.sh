#!/bin/bash
# Verify GitHub OAuth App client credentials are configured and GitHub's OAuth
# endpoints are reachable. Real client_id/secret validation requires a user
# auth flow — see exchange_github_token.sh for that.
#
# Outputs JSON: {"integration":"github_oauth","status":"ok"|"error",...}

set -u

errors=()

if [ -z "${GITHUB_CLIENT_ID:-}" ]; then
  errors+=("GITHUB_CLIENT_ID is not set")
fi

if [ -z "${GITHUB_CLIENT_SECRET:-}" ]; then
  errors+=("GITHUB_CLIENT_SECRET is not set")
fi

if [ ${#errors[@]} -gt 0 ]; then
  joined=$(printf '%s; ' "${errors[@]}" | sed 's/; $//')
  printf '{"integration":"github_oauth","status":"error","error":"config","details":"%s"}\n' "$joined"
  exit 1
fi

reachable=$(curl -sS -o /dev/null -w "%{http_code}" https://api.github.com)
if [ "$reachable" != "200" ]; then
  printf '{"integration":"github_oauth","status":"error","error":"unreachable","details":"api.github.com returned %s"}\n' "$reachable"
  exit 1
fi

printf '{"integration":"github_oauth","status":"ok","details":"client credentials present; api.github.com reachable. Run exchange_github_token.sh to fully validate."}\n'
exit 0
