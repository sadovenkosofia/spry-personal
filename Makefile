# Deploy contract: CI runs exactly these targets, so any deploy can be reproduced locally.
# Local overrides go in deploy.env (git-ignored), e.g.  CLOUDFRONT_DIST_ID=E123ABC
-include deploy.env
-include .env

AWS_REGION         ?= eu-central-1
AWS_ACCOUNT_ID     ?= $(shell aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY     ?= spry-backend
ECR_REGISTRY       ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
ECS_CLUSTER        ?= spry-cluster
ECS_SERVICE        ?= spry-backend-service
S3_BUCKET          ?= spry-frontend-$(AWS_ACCOUNT_ID)
CLOUDFRONT_DIST_ID ?=
AUTH_REGION        ?= us-east-1
PROJECT_NAME       ?= demo
# All stack outputs now come from Terraform (HCP Terraform state): terraform output -raw <name>
tf_output = $(shell terraform -chdir=infra output -raw $(1))
IMAGE_TAG          ?= $(shell git rev-parse HEAD)
IMAGE              = $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG)
TASK_DEF           = $(shell aws ecs describe-services --region $(AWS_REGION) --cluster $(ECS_CLUSTER) --services $(ECS_SERVICE) --query 'services[0].taskDefinition' --output text)
TASK_FAMILY        = $(firstword $(subst :, ,$(notdir $(TASK_DEF))))

.PHONY: up-local deploy-frontend deploy-backend

# Local development
up-local:
	docker compose up --build
deploy-frontend: export VITE_COGNITO_USER_POOL_ID = $(call tf_output,user_pool_id)
deploy-frontend: export VITE_COGNITO_CLIENT_ID    = $(call tf_output,user_pool_client_id)
deploy-frontend: export VITE_COGNITO_DOMAIN       = $(call tf_output,cognito_domain)
deploy-frontend: export VITE_PARSER_URL = $(call tf_output,parser_url)
# build the bundle, sync to S3, invalidate CloudFront
deploy-frontend:
ifndef CLOUDFRONT_DIST_ID
	$(error CLOUDFRONT_DIST_ID is not set)
endif
	cd frontend && npm ci && npm run build
	aws s3 sync frontend/dist/ s3://$(S3_BUCKET)/ --delete
	aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_DIST_ID) --paths "/*"

# build the image (tagged with the commit SHA), push to ECR, roll the ECS service
deploy-backend:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_REGISTRY)
	docker build -t $(IMAGE) ./backend
	docker push $(IMAGE)
	aws ecs describe-task-definition --region $(AWS_REGION) --task-definition $(TASK_FAMILY) --query taskDefinition \
	  | jq --arg IMG "$(IMAGE)" 'del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy) | .containerDefinitions[0].image=$$IMG' > /tmp/taskdef.json
	aws ecs register-task-definition --region $(AWS_REGION) --cli-input-json file:///tmp/taskdef.json > /dev/null
	aws ecs update-service --region $(AWS_REGION) --cluster $(ECS_CLUSTER) --service $(ECS_SERVICE) --task-definition $(TASK_FAMILY)

# ---------------------------------------------------------------- weekly report (infra/base.tf, builder.tf, mailer.tf, schedule.tf)
# IMAGE_TAG comes from `git rev-parse HEAD`,
# so commit before building, or pass IMAGE_TAG=something.
REPORTS_IMAGE_TAG  ?= reports-$(IMAGE_TAG)
REPORTS_IMAGE      = $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(REPORTS_IMAGE_TAG)

.PHONY: build-reports-image report-now

# build the builder-Lambda image and push it next to the backend image.
# --provenance=false: Lambda rejects the attestation manifests BuildKit adds by default.
build-reports-image:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_REGISTRY)
	docker build --platform linux/amd64 --provenance=false -f backend/Dockerfile.lambda -t $(REPORTS_IMAGE) ./backend
	docker push $(REPORTS_IMAGE)

# build (or rebuild) the report of one week on demand:  make report-now WEEK=2026-W41
report-now:
ifndef WEEK
	$(error WEEK is not set, e.g. make report-now WEEK=2026-W41)
endif
	aws sqs send-message --region $(AWS_REGION) --queue-url $(call tf_output,queue_url) --message-body '{"week": "$(WEEK)", "source": "manual"}'

# ---------------------------------------------------------------- AI agenda parser
PARSER_MODEL ?= us.anthropic.claude-haiku-4-5-20251001-v1:0
export PARSER_MODEL

.PHONY: llm-hello parse

# first call to the model from the laptop
llm-hello:
	python backend/scripts/llm_hello.py

# run the parser function locally:  make parse TEXT="..."
parse:
	cd backend && python -m app.ai.agenda


# ---------------------------------------------------------------- agenda parser Lambda (infra/ai.tf)
AI_IMAGE_TAG  ?= ai-$(IMAGE_TAG)
AI_IMAGE      = $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(AI_IMAGE_TAG)

.PHONY: build-ai-image

# same image recipe as the reports builder, another tag
build-ai-image:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_REGISTRY)
	docker build --platform linux/amd64 --provenance=false -f backend/Dockerfile.lambda -t $(AI_IMAGE) ./backend
	docker push $(AI_IMAGE)


# ---------------------------------------------------------------- infrastructure (Terraform, infra/)
# Infrastructure changes go through a pull request; HCP Terraform applies after merge.
# There is deliberately no apply target here. After build-*-image, put the new image tag
# into infra/terraform.tfvars (builder_image_uri / parser_image_uri) and open a PR.
.PHONY: infra-init infra-fmt infra-validate infra-plan
infra-init:
	terraform -chdir=infra init
infra-fmt:
	terraform -chdir=infra fmt -check
infra-validate:
	terraform -chdir=infra validate
# speculative plan in HCP Terraform, changes nothing
infra-plan:
	terraform -chdir=infra plan
