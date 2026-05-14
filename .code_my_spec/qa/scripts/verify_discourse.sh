#!/bin/bash
# Verify ElixirForum public read access (anonymous; v1 is read-only).
# Outputs JSON: {"integration":"discourse","status":"ok"|"error",...}

set -u

response=$(curl -sS -o /tmp/discourse_resp.$$ -w "%{http_code}" \
  -H "Accept: application/json" \
  -A "MarketMySpec/0.1 verify-discourse" \
  https://elixirforum.com/latest.json)
status=$?
body=$(cat /tmp/discourse_resp.$$ 2>/dev/null || echo "")
rm -f /tmp/discourse_resp.$$

if [ $status -ne 0 ]; then
  printf '{"integration":"discourse","status":"error","error":"network","details":"curl exit %s"}\n' "$status"
  exit 1
fi

if [ "$response" = "200" ]; then
  has_topics=$(printf '%s' "$body" | python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); tl=d.get("topic_list") or {}; print("yes" if tl.get("topics") else "no")' 2>/dev/null || echo "no")
  if [ "$has_topics" = "yes" ]; then
    printf '{"integration":"discourse","status":"ok","details":"GET /latest.json returned 200 with topic_list.topics; anonymous read access confirmed"}\n'
    exit 0
  fi
  printf '{"integration":"discourse","status":"error","error":"unexpected_shape","details":"200 OK but no topic_list.topics in response"}\n'
  exit 1
fi

printf '{"integration":"discourse","status":"error","error":"http_%s","details":%s}\n' "$response" "$(printf '%s' "$body" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$body")"
exit 1
