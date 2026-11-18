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


## Google Cloud (Lab 9)

What runs where, and why:

| Piece | Where it runs | Notes |
|---|---|---|
| Frontend | **Firebase Hosting** (Google Cloud, Spark plan, no billing needed) | `https://avid-sphere-510417-m1.web.app` |
| API | AWS (ECS), as before | the Firebase frontend calls it through CloudFront (`VITE_API_BASE`), CORS is enabled in `backend/app/main.py` |
| Database | AWS (Aurora), as before | the API on AWS is the only thing that talks to it |
| Sign-in, parser, weekly report | AWS | unchanged |

This is a multicloud split. The full move (Cloud Run, Cloud SQL, Artifact Registry, Secret Manager)
is described in `gcp/*.tf` and passes `terraform validate`, but it was not deployed: those services
need a linked billing account, and the free trial asks for a prepayment. See ADR 0008.

Deploy the frontend (needs `firebase login` and Firebase added to the GCP project):

```
make gcp-deploy-frontend API_BASE=https://<cloudfront-domain>.cloudfront.net GCP_PROJECT=avid-sphere-510417-m1
```

The Firebase URLs must be in `callback_urls`, `logout_urls` and `allowed_origins` of
`infra/terraform.tfvars` so that sign-in and the parser work from the new origin.

With billing (full Google Cloud setup): `make gcp-init`, `make gcp-apply`, `make gcp-deploy-api`,
then `make gcp-deploy-frontend FIREBASE_CONFIG=firebase.cloudrun.json`. Stop the database with
`make gcp-db-stop` (compute stops, 10 GB storage still bills); `make gcp-destroy` removes everything.
