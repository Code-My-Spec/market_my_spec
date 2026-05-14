#!/bin/bash
# Verify Reddit public read access (anonymous; v1 is read-only).
# Outputs JSON: {"integration":"reddit","status":"ok"|"error",...}

set -u

if [ -z "${REDDIT_USER_AGENT:-}" ]; then
  printf '{"integration":"reddit","status":"error","error":"missing_env","details":"REDDIT_USER_AGENT is not set"}\n'
  exit 1
fi

response=$(curl -sS -o /tmp/reddit_resp.$$ -w "%{http_code}" \
  -A "${REDDIT_USER_AGENT}" \
  -H "Accept: application/json" \
  https://www.reddit.com/r/elixir/.json?limit=1)
status=$?
body=$(cat /tmp/reddit_resp.$$ 2>/dev/null || echo "")
rm -f /tmp/reddit_resp.$$

if [ $status -ne 0 ]; then
  printf '{"integration":"reddit","status":"error","error":"network","details":"curl exit %s"}\n' "$status"
  exit 1
fi

if [ "$response" = "200" ]; then
  has_listing=$(printf '%s' "$body" | python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print("yes" if d.get("kind")=="Listing" else "no")' 2>/dev/null || echo "no")
  if [ "$has_listing" = "yes" ]; then
    printf '{"integration":"reddit","status":"ok","details":"GET /r/elixir/.json returned 200 with a Listing; anonymous read access confirmed"}\n'
    exit 0
  fi
  printf '{"integration":"reddit","status":"error","error":"unexpected_shape","details":"200 OK but response was not a Listing"}\n'
  exit 1
fi

printf '{"integration":"reddit","status":"error","error":"http_%s","details":%s}\n' "$response" "$(printf '%s' "$body" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$body")"
exit 1
