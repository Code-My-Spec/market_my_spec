#!/usr/bin/env bash
set -euo pipefail

# bootstrap_iam.sh
#
# Creates IAM users for market-my-spec UAT and prod file storage, attaches
# bucket-scoped policies, then generates and prints access key credentials.
#
# Operator workflow:
#   1. Run this script. Copy the printed key + secret.
#   2. Set them as Fly.io secrets (once fly.toml exists):
#        fly secrets set AWS_ACCESS_KEY_ID=<key> AWS_SECRET_ACCESS_KEY=<secret> -a <app>
#   3. Do NOT paste credentials into any file in this repo.
#
# Prerequisites:
#   - aws CLI installed and configured with admin credentials
#   - S3 buckets already created (run bootstrap_buckets.sh first)
#
# Usage:
#   ./scripts/aws/bootstrap_iam.sh
#   ./scripts/aws/bootstrap_iam.sh uat    # single env only
#   ./scripts/aws/bootstrap_iam.sh prod   # single env only

ENVS=("uat" "prod")

# If an env argument is given, scope to just that env
if [[ $# -gt 0 ]]; then
  ENVS=("$1")
fi

for ENV in "${ENVS[@]}"; do
  BUCKET="market-my-spec-${ENV}"
  USER="mms-${ENV}-files"
  POLICY_NAME="mms-${ENV}-files-bucket-access"

  echo ""
  echo "=== Configuring IAM user: ${USER} ==="

  # 1. Create IAM user (idempotent — EntityAlreadyExists is not an error)
  echo "  Creating IAM user..."
  aws iam create-user --user-name "${USER}" 2>&1 | \
    grep -v "EntityAlreadyExists" || true

  # 2. Attach inline policy scoped to this env's bucket
  echo "  Attaching bucket policy..."
  POLICY_DOCUMENT=$(cat <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BucketLevelAccess",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::${BUCKET}"
    },
    {
      "Sid": "ObjectLevelAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::${BUCKET}/*"
    }
  ]
}
POLICY
)
  aws iam put-user-policy \
    --user-name "${USER}" \
    --policy-name "${POLICY_NAME}" \
    --policy-document "${POLICY_DOCUMENT}"

  # 3. Create access key and print credentials
  echo ""
  echo "  === Credentials for ${USER} (copy now — secret is shown once) ==="
  aws iam create-access-key --user-name "${USER}" --output json | \
    python3 -c "
import sys, json
creds = json.load(sys.stdin)['AccessKey']
print(f\"  AWS_ACCESS_KEY_ID     = {creds['AccessKeyId']}\")
print(f\"  AWS_SECRET_ACCESS_KEY = {creds['SecretAccessKey']}\")
"

  echo ""
  echo "  To set on Fly.io (once fly.toml exists):"
  echo "    fly secrets set AWS_ACCESS_KEY_ID=<key> AWS_SECRET_ACCESS_KEY=<secret> -a <app-name>"
  echo "  Done: ${USER}"
done

echo ""
echo "IAM setup complete. Store credentials in your secrets manager, not in this repo."
