# Use Hetzner Cloud with Docker Compose for deployment

## Status
Accepted (pre-made)

## Context
We need a deployment target that is cost-effective, performant, and supports multi-environment hosting (prod + UAT) on a single server.

## Decision
Deploy to a Hetzner cax11 ARM64 server running Docker Compose with Caddy as the reverse proxy. Use the internal DevOps knowledge base for implementation guidance — run `search_knowledge` with query "hetzner" or `read_knowledge` with path "devops/hetzner-docker-deploy.md" for the full deployment playbook covering server provisioning, Docker Compose stack, Caddy config, Postgres backups, and zero-downtime deploys via docker-rollout.

## Consequences
This is a pre-made decision for the standard CodeMySpec stack.
