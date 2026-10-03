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
AUTH_STACK         ?= spry-auth
PROJECT_NAME       ?= demo
auth_output = $(shell aws cloudformation describe-stacks --region $(AUTH_REGION) --stack-name $(AUTH_STACK) --query "Stacks[0].Outputs[?OutputKey=='$(1)'].OutputValue" --output text)
IMAGE_TAG          ?= $(shell git rev-parse HEAD)
IMAGE              = $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG)
TASK_DEF           = $(shell aws ecs describe-services --region $(AWS_REGION) --cluster $(ECS_CLUSTER) --services $(ECS_SERVICE) --query 'services[0].taskDefinition' --output text)
TASK_FAMILY        = $(firstword $(subst :, ,$(notdir $(TASK_DEF))))

PHONY: up-local deploy-frontend deploy-backend deploy-auth

# Local development
up-local:
	docker compose up --build
deploy-frontend: export VITE_COGNITO_USER_POOL_ID = $(call auth_output,UserPoolId)
deploy-frontend: export VITE_COGNITO_CLIENT_ID    = $(call auth_output,UserPoolClientId)
deploy-frontend: export VITE_COGNITO_DOMAIN       = $(call auth_output,CognitoDomain)
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

# deploy the Cognito user pool (always in us-east-1)
deploy-auth:
ifndef GOOGLE_CLIENT_ID
	$(error GOOGLE_CLIENT_ID is not set, put it in .env)
endif
ifndef GOOGLE_CLIENT_SECRET
	$(error GOOGLE_CLIENT_SECRET is not set, put it in .env)
endif
	@aws cloudformation deploy --region $(AUTH_REGION) --stack-name $(AUTH_STACK) \
	  --template-file infra/auth.yml \
	  --parameter-overrides ProjectName=$(PROJECT_NAME) GoogleClientId=$(GOOGLE_CLIENT_ID) GoogleClientSecret=$(GOOGLE_CLIENT_SECRET) \
	  --tags PROJECT_NAME=$(PROJECT_NAME)
