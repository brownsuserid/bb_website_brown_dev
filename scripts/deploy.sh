#!/bin/bash
#
# deploy.sh - Unified deployment for bb-web-home
#
# Usage:
#   ./scripts/deploy.sh [env]
#
# Arguments:
#   env - Environment to deploy (dev|prod), default: dev
#
# Examples:
#   ./scripts/deploy.sh dev   # Deploy to development
#   ./scripts/deploy.sh prod  # Deploy to production (requires confirmation)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENV="${1:-dev}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CDK_DIR="$PROJECT_ROOT/cdk"

echo "=========================================="
echo "bb-web-home Deployment"
echo "=========================================="
echo ""
echo "Environment: $ENV"
echo "Project Root: $PROJECT_ROOT"
echo ""

# Validate environment
if [[ ! "$ENV" =~ ^(dev|prod)$ ]]; then
    echo -e "${RED}ERROR: Invalid environment '$ENV'${NC}"
    echo "Usage: $0 [dev|prod]"
    exit 1
fi

# Production safety confirmation
if [ "$ENV" = "prod" ]; then
    echo -e "${YELLOW}WARNING: You are about to deploy to PRODUCTION${NC}"
    echo ""
    echo "This will:"
    echo "  - Deploy CDK infrastructure to production AWS account"
    echo "  - Update brainbridge.app and brainbridgelabs.ai"
    echo "  - Invalidate CloudFront cache globally"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        exit 0
    fi
fi

# Auto-detect CDK command
if [ -f "$CDK_DIR/package-lock.json" ]; then
    CDK_CMD="npx cdk"
elif [ -f "$CDK_DIR/yarn.lock" ]; then
    CDK_CMD="yarn cdk"
elif [ -f "$CDK_DIR/pnpm-lock.yaml" ]; then
    CDK_CMD="pnpm cdk"
else
    CDK_CMD="npx cdk"
fi

echo "Using CDK command: $CDK_CMD"
echo ""

# Step 1: Build Astro site
echo "=========================================="
echo "Step 1: Building Astro Site"
echo "=========================================="
echo ""

cd "$PROJECT_ROOT"
chmod +x scripts/build.sh
./scripts/build.sh

# Step 2: Deploy CDK infrastructure
echo ""
echo "=========================================="
echo "Step 2: Deploying CDK Infrastructure"
echo "=========================================="
echo ""

cd "$CDK_DIR"

# Install CDK dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing CDK dependencies..."
    npm install
fi

# Construct stack name based on environment
# Convert first letter to uppercase (bash 3.2 compatible)
ENV_UPPER="$(echo "${ENV:0:1}" | tr '[:lower:]' '[:upper:]')${ENV:1}"
STACK_NAME="BBWebHome${ENV_UPPER}Stack"  # dev -> BBWebHomeDevStack

echo "Deploying stack: $STACK_NAME"
echo ""

if ! $CDK_CMD deploy "$STACK_NAME" --require-approval never --context environment="$ENV"; then
    echo -e "${RED}ERROR: CDK deployment failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Run 'cd cdk && npm run build' to check for TypeScript errors"
    echo "  2. Run 'cd cdk && $CDK_CMD synth' to validate templates"
    echo "  3. Check AWS credentials: aws sts get-caller-identity"
    exit 1
fi

echo -e "${GREEN}✓ CDK deployment complete${NC}"
echo ""

# Step 3: Extract outputs from CDK
echo "=========================================="
echo "Step 3: Extracting CDK Outputs"
echo "=========================================="
echo ""

# Query AWS CloudFormation for outputs
BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" --output text 2>/dev/null || echo "")
DISTRIBUTION_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='DistributionId'].OutputValue" --output text 2>/dev/null || echo "")

if [ -z "$BUCKET_NAME" ] || [ -z "$DISTRIBUTION_ID" ]; then
    echo -e "${RED}ERROR: Could not extract CDK outputs${NC}"
    echo "Bucket: $BUCKET_NAME"
    echo "Distribution: $DISTRIBUTION_ID"
    echo ""
    echo "This might be the first deployment. Outputs should be available after stack creation completes."
    exit 1
fi

echo "S3 Bucket: $BUCKET_NAME"
echo "CloudFront Distribution: $DISTRIBUTION_ID"
echo ""

# Step 4: Sync assets to S3
echo "=========================================="
echo "Step 4: Syncing Assets to S3"
echo "=========================================="
echo ""

cd "$PROJECT_ROOT"

# Sync all files except HTML (with caching)
echo "Syncing static assets..."
aws s3 sync dist/ "s3://$BUCKET_NAME/" \
    --exclude "*.html" \
    --cache-control "public, max-age=31536000, immutable" \
    --delete

# Upload HTML files with no-cache headers
echo "Uploading HTML files (no-cache)..."
find dist -name "*.html" -type f | while read -r file; do
    key="${file#dist/}"
    aws s3 cp "$file" "s3://$BUCKET_NAME/$key" \
        --content-type "text/html" \
        --cache-control "no-cache, no-store, must-revalidate"
done

echo -e "${GREEN}✓ S3 sync complete${NC}"
echo ""

# Step 5: Invalidate CloudFront cache
echo "=========================================="
echo "Step 5: Invalidating CloudFront Cache"
echo "=========================================="
echo ""

INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id "$DISTRIBUTION_ID" \
    --paths "/*" \
    --query 'Invalidation.Id' \
    --output text)

echo "Invalidation ID: $INVALIDATION_ID"
echo "Status: In Progress"
echo ""
echo "Note: Cache invalidation typically takes 1-5 minutes to complete globally"
echo ""

# Step 6: Deployment summary
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Environment: $ENV"
echo "S3 Bucket: $BUCKET_NAME"
echo "CloudFront Distribution: $DISTRIBUTION_ID"
echo ""

if [ "$ENV" = "dev" ]; then
    CLOUDFRONT_URL=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='DistributionDomainName'].OutputValue" --output text 2>/dev/null || echo "")
    if [ -n "$CLOUDFRONT_URL" ]; then
        echo "Development URL: https://$CLOUDFRONT_URL"
    fi
else
    echo "Production URLs:"
    echo "  - https://brainbridge.app"
    echo "  - https://brainbridgelabs.ai (after DNS migration)"
    echo ""
    
    # Check for nameserver outputs
    NS_OUTPUT=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?contains(OutputKey, 'NameServers')].{Key:OutputKey,Value:OutputValue}" --output json 2>/dev/null || echo "[]")
    
    if [ "$NS_OUTPUT" != "[]" ]; then
        echo -e "${YELLOW}ACTION REQUIRED: Update nameservers at your domain registrar${NC}"
        echo ""
        echo "$NS_OUTPUT" | jq -r '.[] | "\(.Key):\n  \(.Value)\n"'
    fi
fi

echo ""
echo -e "${GREEN}✓ Deployment successful!${NC}"
echo ""

# Optional: Wait for invalidation to complete
read -p "Wait for CloudFront invalidation to complete? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Waiting for invalidation..."
    aws cloudfront wait invalidation-completed \
        --distribution-id "$DISTRIBUTION_ID" \
        --id "$INVALIDATION_ID"
    echo -e "${GREEN}✓ Cache invalidation complete${NC}"
fi
