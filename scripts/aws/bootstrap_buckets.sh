#!/usr/bin/env bash
set -euo pipefail

# bootstrap_buckets.sh
#
# Creates and configures S3 buckets for market-my-spec UAT and prod environments.
# Run this once with admin AWS credentials before deploying either environment.
#
# Prerequisites:
#   - aws CLI installed and configured with admin credentials
#   - Region: us-east-1
#
# Usage:
#   ./scripts/aws/bootstrap_buckets.sh
#   ./scripts/aws/bootstrap_buckets.sh uat    # single env only
#   ./scripts/aws/bootstrap_buckets.sh prod   # single env only

REGION="us-east-1"
ENVS=("uat" "prod")

# If an env argument is given, scope to just that env
if [[ $# -gt 0 ]]; then
  ENVS=("$1")
fi

for ENV in "${ENVS[@]}"; do
  BUCKET="market-my-spec-${ENV}"
  echo ""
  echo "=== Configuring bucket: ${BUCKET} ==="

  # 1. Create bucket (idempotent — BucketAlreadyOwnedByYou is not an error)
  echo "  Creating bucket..."
  aws s3api create-bucket \
    --bucket "${BUCKET}" \
    --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}" 2>&1 | \
    grep -v "BucketAlreadyOwnedByYou" || true

  # 2. Block all public access
  echo "  Blocking public access..."
  aws s3api put-public-access-block \
    --bucket "${BUCKET}" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  # 3. Enable SSE-S3 (AES-256) encryption
  echo "  Enabling server-side encryption (AES-256)..."
  aws s3api put-bucket-encryption \
    --bucket "${BUCKET}" \
    --server-side-encryption-configuration '{
      "Rules": [
        {
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
          },
          "BucketKeyEnabled": true
        }
      ]
    }'

  # 4. Enable versioning (required for noncurrent-version lifecycle rules)
  echo "  Enabling versioning..."
  aws s3api put-bucket-versioning \
    --bucket "${BUCKET}" \
    --versioning-configuration Status=Enabled

  # 5. Lifecycle rule: expire noncurrent versions after 30 days and clean up
  #    delete markers automatically
  echo "  Configuring lifecycle policy (30-day noncurrent expiry)..."
  aws s3api put-bucket-lifecycle-configuration \
    --bucket "${BUCKET}" \
    --lifecycle-configuration '{
      "Rules": [
        {
          "ID": "expire-noncurrent-versions-30d",
          "Status": "Enabled",
          "Filter": {
            "Prefix": ""
          },
          "NoncurrentVersionExpiration": {
            "NoncurrentDays": 30
          },
          "ExpiredObjectDeleteMarker": true
        }
      ]
    }'

  echo "  Done: ${BUCKET}"
done

echo ""
echo "All buckets configured. Run bootstrap_iam.sh next to create IAM users."
