#!/bin/sh
# Boot wrapper for the sops-based secrets path (CodeMySpec-managed deploys).
# Decrypts envs/$APP_ENV.enc.env with SOPS_AGE_KEY and execs the release
# with those values in its environment. Not used by the existing
# AWS-SSM-based boot (bin/server) — this is a separate, additive path.
set -eu

ENV_NAME="${APP_ENV:?APP_ENV must be set (prod|uat)}"
ENV_FILE="/app/envs/${ENV_NAME}.enc.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "cms_boot: no $ENV_FILE in this image" >&2
  exit 1
fi

if [ -z "${SOPS_AGE_KEY:-}" ]; then
  echo "cms_boot: SOPS_AGE_KEY is not set, cannot decrypt $ENV_FILE" >&2
  exit 1
fi

exec sops exec-env --input-type dotenv "$ENV_FILE" "/app/bin/server"
