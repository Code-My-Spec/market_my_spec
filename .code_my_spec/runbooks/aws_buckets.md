# AWS Buckets Runbook

One-time setup for S3 buckets and IAM users used by the Files backend in UAT and prod.

## Prerequisites

- `aws` CLI installed (`brew install awscli`)
- Admin AWS credentials configured (`aws configure` or `AWS_PROFILE` env var)
- For Fly.io steps: `fly` CLI installed, app names known

## Step 1: Create and configure the S3 buckets

Run once with admin credentials. The script is idempotent — safe to re-run.

```bash
chmod +x scripts/aws/bootstrap_buckets.sh
./scripts/aws/bootstrap_buckets.sh
```

This creates:
- `market-my-spec-uat` and `market-my-spec-prod` in `us-east-1`
- All public access blocked
- SSE-S3 (AES-256) encryption enabled
- Versioning enabled
- Lifecycle rule: noncurrent versions expire after 30 days, delete markers auto-cleaned

To run for a single environment:
```bash
./scripts/aws/bootstrap_buckets.sh uat
./scripts/aws/bootstrap_buckets.sh prod
```

## Step 2: Create IAM users and capture credentials

```bash
chmod +x scripts/aws/bootstrap_iam.sh
./scripts/aws/bootstrap_iam.sh
```

The script creates:
- `mms-uat-files` with policy scoped to `market-my-spec-uat`
- `mms-prod-files` with policy scoped to `market-my-spec-prod`
- One access key per user, printed to stdout once

**Copy the printed credentials immediately.** AWS does not show the secret again.

Do NOT paste credentials into any file in this repo. Use your secrets manager or
deploy-platform secrets.

## Step 3: Push credentials to Fly.io

Note: `fly.toml` does not yet exist. These commands are forward-looking — run them
once the app is deployed and the app name is known.

```bash
# UAT
fly secrets set \
  AWS_ACCESS_KEY_ID=<mms-uat-files-access-key> \
  AWS_SECRET_ACCESS_KEY=<mms-uat-files-secret> \
  AWS_REGION=us-east-1 \
  S3_BUCKET=market-my-spec-uat \
  -a <uat-app-name>

# Prod
fly secrets set \
  AWS_ACCESS_KEY_ID=<mms-prod-files-access-key> \
  AWS_SECRET_ACCESS_KEY=<mms-prod-files-secret> \
  AWS_REGION=us-east-1 \
  S3_BUCKET=market-my-spec-prod \
  -a <prod-app-name>
```

## Step 4: Verify the bucket works

From a machine with the IAM credentials in the environment:

```bash
# List the bucket (should return empty initially)
aws s3 ls s3://market-my-spec-uat

# Quick round-trip smoke test via IEx (requires app config to be loaded)
MIX_ENV=prod mix run --no-start -e '
Application.ensure_all_started(:market_my_spec)
key = "smoke-test/hello.txt"
{:ok, _meta} = MarketMySpec.Files.S3.put(key, "hello", content_type: "text/plain")
{:ok, body} = MarketMySpec.Files.S3.get(key)
IO.inspect(body, label: "body")
:ok = MarketMySpec.Files.S3.delete(key)
IO.puts("Round-trip OK")
'
```

## Rollback notes

If you need to tear down a bucket or user:

```bash
# Delete all objects first (required before bucket deletion)
aws s3 rm s3://market-my-spec-uat --recursive

# Delete the bucket
aws s3api delete-bucket --bucket market-my-spec-uat --region us-east-1

# Delete IAM access keys (list first to get the key ID)
aws iam list-access-keys --user-name mms-uat-files
aws iam delete-access-key --user-name mms-uat-files --access-key-id <key-id>

# Delete the inline policy
aws iam delete-user-policy --user-name mms-uat-files --policy-name mms-uat-files-bucket-access

# Delete the user
aws iam delete-user --user-name mms-uat-files
```

Rollback is manual and destructive. All stored files will be lost. Confirm before running.
