# Deploy contract: CI runs exactly these targets, so any deploy can be reproduced locally.
# Local overrides go in deploy.env (git-ignored), e.g.  CLOUDFRONT_DIST_ID=E123ABC
-include deploy.env

AWS_REGION         ?= eu-central-1
AWS_ACCOUNT_ID     ?= $(shell aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY     ?= spry-backend
ECR_REGISTRY       ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
ECS_CLUSTER        ?= spry-cluster
ECS_SERVICE        ?= spry-backend-service
S3_BUCKET          ?= spry-frontend-$(AWS_ACCOUNT_ID)
CLOUDFRONT_DIST_ID ?=
IMAGE_TAG          ?= $(shell git rev-parse HEAD)

.PHONY: up-local deploy-frontend deploy-backend

# Local development
up-local:
	docker compose up --build

# build the bundle, sync to S3, invalidate CloudFront
deploy-frontend:
	@test -n "$(CLOUDFRONT_DIST_ID)" || (echo CLOUDFRONT_DIST_ID is not set && exit 1)
	cd frontend && npm ci && npm run build
	aws s3 sync frontend/dist/ s3://$(S3_BUCKET)/ --delete
	aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_DIST_ID) --paths "/*"

# build the image (tagged with the commit SHA), push to ECR, roll the ECS service
deploy-backend:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_REGISTRY)
	docker build -t $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG) -t $(ECR_REGISTRY)/$(ECR_REPOSITORY):latest ./backend
	docker push $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG)
	docker push $(ECR_REGISTRY)/$(ECR_REPOSITORY):latest
	aws ecs update-service --region $(AWS_REGION) --cluster $(ECS_CLUSTER) --service $(ECS_SERVICE) --force-new-deployment
