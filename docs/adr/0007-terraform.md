# ADR 0007: Terraform and HCP Terraform replace CloudFormation

Status: accepted

## Context

The AWS infrastructure (Cognito user pool with Google sign-in, the weekly report
pipeline, the agenda parser Lambda) lived in three CloudFormation templates
(`infra/auth.yml`, `infra/reports.yml`, `infra/ai.yml`) deployed from a laptop with
`make deploy-*`. Anyone with AWS credentials could change production, there was no
review step, and secrets were passed on the command line.

## Decision

We describe the infrastructure in Terraform (`infra/*.tf`, one root module) and run it
in one HCP Terraform workspace, `demo-dev`, with remote execution.

Why Terraform and not the alternatives:

- CloudFormation: works, but has no plan-then-review workflow comparable to
  `terraform plan`, drift detection is manual, and the templates were tied to AWS only.
  Stack outputs also needed custom shell lookups in the Makefile.
- CDK: adds a general-purpose language and a build step on top of CloudFormation.
  For about 30 resources, plain declarative HCL is easier to review in a PR.
- OpenTofu: a compatible fork and a valid choice. We chose Terraform because HCP
  Terraform (remote runs, state storage, OIDC credentials) is a managed service for
  Terraform and removes the need to run our own backend.

The existing resources were adopted with `import` blocks, not recreated. They were
protected during the move by `DeletionPolicy: Retain` and `UpdateReplacePolicy: Retain`
before the stacks were deleted. The Cognito user pool holds real accounts and was never
replaced. The `aws_lambda_permission` resources and the S3 bucket notification were
created fresh.

## Who can change the infrastructure, and how

1. Open a pull request that changes `infra/`.
2. HCP Terraform runs a speculative plan on the PR; a reviewer reads it.
3. After merge to the main branch, HCP Terraform plans and applies in the workspace.
4. Nobody runs `terraform apply` from a laptop, and the Makefile has no apply target.
   `make infra-plan` only shows a plan.

HCP Terraform reaches AWS with short-lived credentials through OIDC: the IAM role
`hcp-terraform-ooad-sadovenkosofia` trusts only the organization `ooad-sadovenkosofia`.
No long-lived AWS keys are stored in the workspace.

## Where secrets go

- `google_client_secret` and `database_url` are sensitive Terraform variables of the
  workspace. They are never in Git or in `terraform.tfvars`.
- Terraform state is stored in HCP Terraform. State can contain secret values
  (for example the Google client secret), so access to the workspace and its state
  must be limited to the people who may already see those secrets.
- `DATABASE_URL` of the builder Lambda is a known exception: Terraform cannot compare
  it reliably, so the resource uses `ignore_changes = [environment]` and the value is
  managed outside Terraform. Changing it needs a deliberate manual step.
- `infra/terraform.tfvars` holds only non-secret values (URLs, VPC and subnet IDs,
  image URIs).

## If HCP Terraform is down

Running infrastructure keeps working: HCP Terraform is only the control plane, not part
of the request path. What stops is changing infrastructure through the normal flow.
For an urgent fix we would use the AWS console or CLI and then bring Terraform back in
line, which shows up as drift in the next plan. The state itself can be downloaded from
the workspace while it is available, and a local backend could be configured from it
as a last resort. We do not keep a second backend ready, because the cost outweighs the
risk for a project of this size.

## Consequences and known limits

- The HCP Terraform role has `AdministratorAccess`. This is a deliberate shortcut for
  this lab. Narrowing it to the services we use (Cognito, S3, SQS, Lambda, IAM, Logs,
  SES, Scheduler, EC2 endpoints) is a follow-up.
- `DATABASE_URL` is outside Terraform (see above).
- The network stacks (VPC, subnets, security group, route table) still live in
  CloudFormation and are referenced through variables.
- A new Lambda image requires a PR that changes the image URI in `terraform.tfvars`.
