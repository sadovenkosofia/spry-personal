# Spry

## Infrastructure (Terraform)

The AWS infrastructure (Cognito, weekly report pipeline, agenda parser Lambda) is
described in `infra/*.tf` and managed with Terraform through the HCP Terraform
workspace `demo-dev` (organization `ooad-sadovenkosofia`). It replaced the
CloudFormation templates `infra/auth.yml`, `infra/reports.yml` and `infra/ai.yml`.
See `docs/adr/0007-terraform.md` for the decision.

- Change infrastructure only through a pull request: HCP Terraform runs a plan on
  the PR and applies after merge. Do not run `terraform apply` from a laptop.
- Preview locally: `make infra-init` once, then `make infra-plan` (needs `terraform login`).
- Secrets (`google_client_secret`, `database_url`) are sensitive variables of the
  HCP workspace and are never committed. `infra/terraform.tfvars` holds only
  non-secret values.
- New Lambda image: `make build-reports-image` or `make build-ai-image`, then update
  `builder_image_uri` / `parser_image_uri` in `infra/terraform.tfvars` in a PR.
- Frontend deploy (`make deploy-frontend`) reads Cognito and parser values from
  `terraform output`, so it needs access to the workspace state.

