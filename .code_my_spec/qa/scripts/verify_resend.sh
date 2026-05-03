#!/bin/bash
# Verify Resend API credentials by listing domains for the API key's account.
# Outputs JSON: {"integration":"resend","status":"ok"|"error",...}

set -u

if [ -z "${RESEND_API_KEY:-}" ]; then
  printf '{"integration":"resend","status":"error","error":"missing_env","details":"RESEND_API_KEY is not set"}\n'
  exit 1
fi

response=$(curl -sS -o /tmp/resend_resp.$$ -w "%{http_code}" \
  -H "Authorization: Bearer ${RESEND_API_KEY}" \
  -H "Content-Type: application/json" \
  https://api.resend.com/domains)
status=$?
body=$(cat /tmp/resend_resp.$$ 2>/dev/null || echo "")
rm -f /tmp/resend_resp.$$

if [ $status -ne 0 ]; then
  printf '{"integration":"resend","status":"error","error":"network","details":"curl exit %s"}\n' "$status"
  exit 1
fi

if [ "$response" = "200" ]; then
  printf '{"integration":"resend","status":"ok","details":"GET /domains returned 200; API key authenticated"}\n'
  exit 0
fi

printf '{"integration":"resend","status":"error","error":"http_%s","details":%s}\n' "$response" "$(printf '%s' "$body" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$body")"
exit 1
