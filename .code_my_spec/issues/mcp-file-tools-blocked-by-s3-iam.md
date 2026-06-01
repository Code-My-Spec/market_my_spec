# MMS MCP file-management tools return 403 AccessDenied (s3:ListBucket IAM policy missing)

Filed 2026-05-22 from MMS MCP usage during the CodeMySpec marketing cycle. New gap discovered while trying to determine whether MMS had an issues-writing surface.

## Problem

`mcp__market-my-spec__list_files` (and presumably `read_file`, `write_file`, `edit_file`, `delete_file` by extension) fail on prod with:

```
{:http_error, 403, %{
  body: "<Error><Code>AccessDenied</Code><Message>User: arn:aws:iam::889081505590:user/market-my-spec-prod-app is not authorized to perform: s3:ListBucket on resource: \"arn:aws:s3:::market-my-spec-prod\" because no identity-based policy allows the s3:ListBucket action</Message>...</Error>",
  status_code: 403
}}
```

The prod-app IAM user lacks `s3:ListBucket` permission on the `market-my-spec-prod` bucket.

## Why it matters

The file-management tools are documented but unusable on prod. Today's session wanted to use them as the natural surface for writing MMS issues files — couldn't. Had to fall back to local file writes in the MMS repo's `.code_my_spec/issues/` directory.

Beyond writing issues, any future operator workflow that depends on the MMS account's S3-backed file store (knowledge docs, agent playbooks, custom content) is blocked.

## Acceptance criteria

1. Update the `market-my-spec-prod-app` IAM user's policy to include at minimum:
   - `s3:ListBucket` on `arn:aws:s3:::market-my-spec-prod`
   - `s3:GetObject` on `arn:aws:s3:::market-my-spec-prod/*`
   - `s3:PutObject` on `arn:aws:s3:::market-my-spec-prod/*`
   - `s3:DeleteObject` on `arn:aws:s3:::market-my-spec-prod/*`
2. Verify with `mcp__market-my-spec__list_files` returning a non-error response (empty list is fine — the IAM block is what we're fixing).
3. Verify `write_file` + `read_file` round-trip on a test path.
4. Check whether the dev MMS IAM user has the same gap; if yes, fix in parallel.

## Out of scope

- Per-account S3 path scoping (operators only seeing their own files). Defer until multi-account file isolation is a real requirement.
- File-tool docstring updates pointing operators at use cases. Worth doing once the tools actually work.

## Reference

- Caller-side discovery: `code_my_spec_marketing/marketing/daily/2026-05-22.md` (MMS gap #7, surfaced 2026-05-22 ~13:03 UTC while trying to write these issue files via the MCP)
