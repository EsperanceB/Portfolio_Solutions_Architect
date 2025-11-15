#!/bin/bash

# AWS Portfolio Website - Static Website Deployment Script (Stage 2)
# This script deploys the S3 static website stack and migrates from server-based to serverless

set -e

# Configuration
ENVIRONMENT_NAME="AWSPortfolio"
REGION="us-east-1"
DOMAIN_NAME=""  # Leave empty if not using custom domain
HOSTED_ZONE_ID=""  # Leave empty if not using custom domain
ACM_CERT_ARN=""  # Leave empty if not using HTTPS with custom domain
WEBSITE_DIR="./website"  # Directory containing website files

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Portfolio - Stage 2 Migration${NC}"
echo -e "${GREEN}Serverless Static Website Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to wait for stack completion
wait_for_stack() {
    local stack_name=$1
    echo -e "${YELLOW}Waiting for stack ${stack_name} to complete...${NC}"
    aws cloudformation wait stack-create-complete \
        --stack-name ${stack_name} \
        --region ${REGION}
    echo -e "${GREEN}✓ Stack ${stack_name} created successfully${NC}"
}

# Step 1: Deploy S3 Static Website Stack
echo -e "${YELLOW}Step 1: Deploying S3 Static Website Stack...${NC}"

STACK_PARAMS="ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME}"

if [ ! -z "$DOMAIN_NAME" ]; then
    STACK_PARAMS="${STACK_PARAMS} ParameterKey=DomainName,ParameterValue=${DOMAIN_NAME}"
fi

if [ ! -z "$HOSTED_ZONE_ID" ]; then
    STACK_PARAMS="${STACK_PARAMS} ParameterKey=HostedZoneId,ParameterValue=${HOSTED_ZONE_ID}"
fi

if [ ! -z "$ACM_CERT_ARN" ]; then
    STACK_PARAMS="${STACK_PARAMS} ParameterKey=ACMCertificateArn,ParameterValue=${ACM_CERT_ARN}"
fi

aws cloudformation create-stack \
    --stack-name ${ENVIRONMENT_NAME}-static-website \
    --template-body file://08-s3-static-website-stack.yaml \
    --parameters ${STACK_PARAMS} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${REGION}

wait_for_stack "${ENVIRONMENT_NAME}-static-website"
echo ""

# Step 2: Get bucket name
echo -e "${YELLOW}Step 2: Retrieving S3 bucket information...${NC}"
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name ${ENVIRONMENT_NAME}-static-website \
    --query 'Stacks[0].Outputs[?OutputKey==`WebsiteBucketName`].OutputValue' \
    --output text \
    --region ${REGION})
echo -e "${GREEN}✓ Bucket: ${BUCKET_NAME}${NC}"
echo ""

# Step 3: Upload website files
if [ -d "$WEBSITE_DIR" ]; then
    echo -e "${YELLOW}Step 3: Uploading website files to S3...${NC}"
    aws s3 sync ${WEBSITE_DIR} s3://${BUCKET_NAME}/ --delete --region ${REGION}
    echo -e "${GREEN}✓ Website files uploaded${NC}"
else
    echo -e "${RED}Warning: Website directory ${WEBSITE_DIR} not found${NC}"
    echo -e "${YELLOW}Please upload your website files manually:${NC}"
    echo "aws s3 sync <your-website-dir> s3://${BUCKET_NAME}/ --delete"
fi
echo ""

# Step 4: Get CloudFront distribution ID
echo -e "${YELLOW}Step 4: Creating CloudFront invalidation...${NC}"
DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
    --stack-name ${ENVIRONMENT_NAME}-static-website \
    --query 'Stacks[0].Outputs[?OutputKey==`StaticWebsiteDistributionId`].OutputValue' \
    --output text \
    --region ${REGION})

# Create invalidation
INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id ${DISTRIBUTION_ID} \
    --paths "/*" \
    --query 'Invalidation.Id' \
    --output text \
    --region ${REGION})
echo -e "${GREEN}✓ CloudFront invalidation created: ${INVALIDATION_ID}${NC}"
echo ""

# Step 5: Get website URL
echo -e "${GREEN}Step 5: Deployment Complete!${NC}"
WEBSITE_URL=$(aws cloudformation describe-stacks \
    --stack-name ${ENVIRONMENT_NAME}-static-website \
    --query 'Stacks[0].Outputs[?OutputKey==`StaticWebsiteURL`].OutputValue' \
    --output text \
    --region ${REGION})
echo -e "Your static website is accessible at: ${GREEN}${WEBSITE_URL}${NC}"
echo ""

# Step 6: Cleanup instructions
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Migration Complete!${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Test your static website at: ${WEBSITE_URL}"
echo "2. Verify all microservices still work correctly"
echo "3. Wait for CloudFront distribution to fully deploy (15-20 minutes)"
echo "4. Once verified, you can delete server-based resources to save costs:"
echo ""
echo -e "${RED}Cost Optimization - Delete Server Resources:${NC}"
echo "   aws cloudformation delete-stack --stack-name ${ENVIRONMENT_NAME}-compute --region ${REGION}"
echo "   aws cloudformation delete-stack --stack-name ${ENVIRONMENT_NAME}-cloudfront --region ${REGION}"
echo ""
echo -e "${YELLOW}Note: Keep microservices running as they are still needed for website functionality${NC}"
echo ""
echo -e "${GREEN}Deployed Resources:${NC}"
echo "  ✓ S3 Bucket: ${BUCKET_NAME}"
echo "  ✓ CloudFront Distribution: ${DISTRIBUTION_ID}"
echo "  ✓ Website URL: ${WEBSITE_URL}"
echo ""
