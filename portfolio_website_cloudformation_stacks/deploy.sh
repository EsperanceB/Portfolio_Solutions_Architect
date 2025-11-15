#!/bin/bash

# AWS Portfolio Website - Deployment Script
# This script deploys all CloudFormation stacks in the correct order

set -e

# Configuration
ENVIRONMENT_NAME="AWSPortfolio"
REGION="us-east-1"
AMI_ID="ami-0187c13375421d49b"
INSTANCE_TYPE="t2.micro"
MIN_SIZE=2
MAX_SIZE=4
DESIRED_CAPACITY=2
NOTIFICATION_EMAIL="your-email@example.com"
DOMAIN_NAME=""  # Leave empty if not using custom domain
HOSTED_ZONE_ID=""  # Leave empty if not using custom domain
ACM_CERT_ARN=""  # Leave empty if not using HTTPS with custom domain

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}AWS Portfolio Website Deployment${NC}"
echo -e "${GREEN}====================================${NC}"
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

# Step 1: Deploy Network Stack
echo -e "${YELLOW}Step 1: Deploying Network Stack...${NC}"
aws cloudformation create-stack \
    --stack-name ${ENVIRONMENT_NAME}-network \
    --template-body file://01-network-stack.yaml \
    --parameters ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${REGION}

wait_for_stack "${ENVIRONMENT_NAME}-network"
echo ""

# Step 2: Deploy Microservices (in parallel)
echo -e "${YELLOW}Step 2: Deploying Microservices...${NC}"

echo "  - Deploying View Counter Microservice..."
aws cloudformation create-stack \
    --stack-name ${ENVIRONMENT_NAME}-view-counter \
    --template-body file://03-view-counter-microservice.yaml \
    --parameters ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${REGION}

echo "  - Deploying Blog Microservice..."
aws cloudformation create-stack \
    --stack-name ${ENVIRONMENT_NAME}-blog \
    --template-body file://04-blog-microservice.yaml \
    --parameters ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${REGION}

echo "  - Deploying Contact Form Microservice..."
aws cloudformation create-stack \
    --stack-name ${ENVIRONMENT_NAME}-contact-form \
    --template-body file://05-contact-form-microservice.yaml \
    --parameters ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME} \
                 ParameterKey=NotificationEmail,ParameterValue=${NOTIFICATION_EMAIL} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${REGION}

echo "  - Deploying AWS News Microservice..."
aws cloudformation create-stack \
    --stack-name ${ENVIRONMENT_NAME}-aws-news \
    --template-body file://06-aws-news-microservice.yaml \
    --parameters ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${REGION}

# Wait for all microservices
wait_for_stack "${ENVIRONMENT_NAME}-view-counter"
wait_for_stack "${ENVIRONMENT_NAME}-blog"
wait_for_stack "${ENVIRONMENT_NAME}-contact-form"
wait_for_stack "${ENVIRONMENT_NAME}-aws-news"
echo ""

# Step 3: Display Lambda Function URLs
echo -e "${GREEN}Step 3: Lambda Function URLs${NC}"
echo -e "${YELLOW}Copy these URLs and update your application code:${NC}"
echo ""

VIEW_COUNTER_URL=$(aws cloudformation describe-stacks \
    --stack-name ${ENVIRONMENT_NAME}-view-counter \
    --query 'Stacks[0].Outputs[?OutputKey==`ViewsFunctionUrl`].OutputValue' \
    --output text \
    --region ${REGION})
echo -e "View Counter URL (index.js line 3): ${GREEN}${VIEW_COUNTER_URL}${NC}"

BLOG_VIEWS_URL=$(aws cloudformation describe-stacks \
    --stack-name ${ENVIRONMENT_NAME}-blog \
    --query 'Stacks[0].Outputs[?OutputKey==`BlogViewsFunctionUrl`].OutputValue' \
    --output text \
    --region ${REGION})
echo -e "Blog Views URL (blog.js line 6): ${GREEN}${BLOG_VIEWS_URL}${NC}"

CONTACT_FORM_URL=$(aws cloudformation describe-stacks \
    --stack-name ${ENVIRONMENT_NAME}-contact-form \
    --query 'Stacks[0].Outputs[?OutputKey==`ContactFormFunctionUrl`].OutputValue' \
    --output text \
    --region ${REGION})
echo -e "Contact Form URL (index.js line 34): ${GREEN}${CONTACT_FORM_URL}${NC}"

AWS_NEWS_URL=$(aws cloudformation describe-stacks \
    --stack-name ${ENVIRONMENT_NAME}-aws-news \
    --query 'Stacks[0].Outputs[?OutputKey==`UpdateWebpageFunctionUrl`].OutputValue' \
    --output text \
    --region ${REGION})
echo -e "AWS News URL (aws.js line 2): ${GREEN}${AWS_NEWS_URL}${NC}"
echo ""

# Step 4: Trigger initial RSS fetch
echo -e "${YELLOW}Step 4: Triggering initial RSS fetch...${NC}"
aws lambda invoke \
    --function-name ${ENVIRONMENT_NAME}-RSSFetchFunction \
    --region ${REGION} \
    /tmp/rss-response.json > /dev/null 2>&1
echo -e "${GREEN}✓ RSS feed populated${NC}"
echo ""

# Step 5: Prompt for AMI update
echo -e "${YELLOW}Step 5: AMI Configuration${NC}"
echo -e "${RED}IMPORTANT: Before continuing, you should:${NC}"
echo "1. Launch an EC2 instance from AMI ${AMI_ID}"
echo "2. Update the JavaScript files with the Lambda URLs above"
echo "3. Upload any certification images"
echo "4. Create a new AMI from the configured instance"
echo "5. Update AMI_ID variable in this script with your new AMI ID"
echo ""
read -p "Press Enter when ready to deploy Compute Stack (or Ctrl+C to exit)..."
echo ""

# Step 6: Deploy Compute Stack
echo -e "${YELLOW}Step 6: Deploying Compute Stack...${NC}"
aws cloudformation create-stack \
    --stack-name ${ENVIRONMENT_NAME}-compute \
    --template-body file://02-compute-stack.yaml \
    --parameters ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME} \
                 ParameterKey=AMIId,ParameterValue=${AMI_ID} \
                 ParameterKey=InstanceType,ParameterValue=${INSTANCE_TYPE} \
                 ParameterKey=MinSize,ParameterValue=${MIN_SIZE} \
                 ParameterKey=MaxSize,ParameterValue=${MAX_SIZE} \
                 ParameterKey=DesiredCapacity,ParameterValue=${DESIRED_CAPACITY} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${REGION}

wait_for_stack "${ENVIRONMENT_NAME}-compute"
echo ""

# Step 7: Get ALB DNS
echo -e "${GREEN}Step 7: Application Load Balancer URL${NC}"
ALB_DNS=$(aws cloudformation describe-stacks \
    --stack-name ${ENVIRONMENT_NAME}-compute \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
    --output text \
    --region ${REGION})
echo -e "Your website is accessible at: ${GREEN}http://${ALB_DNS}${NC}"
echo ""

# Step 8: Deploy CloudFront (optional)
if [ ! -z "$DOMAIN_NAME" ]; then
    echo -e "${YELLOW}Step 8: Deploying CloudFront and Route53...${NC}"
    
    CLOUDFRONT_PARAMS="ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME}"
    CLOUDFRONT_PARAMS="${CLOUDFRONT_PARAMS} ParameterKey=DomainName,ParameterValue=${DOMAIN_NAME}"
    
    if [ ! -z "$HOSTED_ZONE_ID" ]; then
        CLOUDFRONT_PARAMS="${CLOUDFRONT_PARAMS} ParameterKey=HostedZoneId,ParameterValue=${HOSTED_ZONE_ID}"
    fi
    
    if [ ! -z "$ACM_CERT_ARN" ]; then
        CLOUDFRONT_PARAMS="${CLOUDFRONT_PARAMS} ParameterKey=ACMCertificateArn,ParameterValue=${ACM_CERT_ARN}"
    fi
    
    aws cloudformation create-stack \
        --stack-name ${ENVIRONMENT_NAME}-cloudfront \
        --template-body file://07-cloudfront-route53-stack.yaml \
        --parameters ${CLOUDFRONT_PARAMS} \
        --capabilities CAPABILITY_NAMED_IAM \
        --region ${REGION}
    
    wait_for_stack "${ENVIRONMENT_NAME}-cloudfront"
    
    CLOUDFRONT_URL=$(aws cloudformation describe-stacks \
        --stack-name ${ENVIRONMENT_NAME}-cloudfront \
        --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' \
        --output text \
        --region ${REGION})
    echo -e "${GREEN}✓ CloudFront deployed${NC}"
    echo -e "CloudFront URL: ${GREEN}${CLOUDFRONT_URL}${NC}"
else
    echo -e "${YELLOW}Step 8: Skipping CloudFront deployment (no domain configured)${NC}"
fi
echo ""

# Final Summary
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Test your website at: http://${ALB_DNS}"
echo "2. Verify all microservices are working (view counter, blog, contact form, AWS news)"
echo "3. (Optional) For Stage 2 migration, run: ./deploy-static-website.sh"
echo ""
echo -e "${YELLOW}Deployed Stacks:${NC}"
echo "  ✓ ${ENVIRONMENT_NAME}-network"
echo "  ✓ ${ENVIRONMENT_NAME}-view-counter"
echo "  ✓ ${ENVIRONMENT_NAME}-blog"
echo "  ✓ ${ENVIRONMENT_NAME}-contact-form"
echo "  ✓ ${ENVIRONMENT_NAME}-aws-news"
echo "  ✓ ${ENVIRONMENT_NAME}-compute"
if [ ! -z "$DOMAIN_NAME" ]; then
    echo "  ✓ ${ENVIRONMENT_NAME}-cloudfront"
fi
echo ""
