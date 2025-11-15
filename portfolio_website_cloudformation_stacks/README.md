# AWS Portfolio Website - CloudFormation Templates

This repository contains CloudFormation templates for deploying a highly available, scalable AWS Portfolio Website with serverless microservices.

## Architecture Overview

The solution is organized into 8 logical CloudFormation stacks:

### Stage 1: Server-Based Deployment

1. **Network Stack** - VPC, Subnets, NAT Gateways, Security Groups
2. **Compute Stack** - Application Load Balancer, Auto Scaling Group, EC2 instances
3. **View Counter Microservice** - Lambda + DynamoDB for page view tracking
4. **Blog Microservice** - S3 + Lambda + DynamoDB for blog post management
5. **Contact Form Microservice** - Lambda + SNS + DynamoDB for contact submissions
6. **AWS News Microservice** - Lambda + DynamoDB + EventBridge for RSS feed updates
7. **CloudFront & Route53 Stack** - CDN distribution and DNS configuration

### Stage 2: Serverless Migration

8. **S3 Static Website Stack** - S3 bucket + CloudFront for fully serverless hosting

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- Domain name (optional, for custom DNS)
- ACM certificate in us-east-1 region (optional, for HTTPS with custom domain)
- AMI ID: `ami-0187c13375421d49b` (or your custom AMI with application code)

## Deployment Order

### Stage 1: Server-Based Architecture

#### Step 1: Deploy Network Infrastructure
```bash
aws cloudformation create-stack \
  --stack-name awsportfolio-network \
  --template-body file://cloudformation/01-network-stack.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=AWSPortfolio \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

Wait for stack completion:
```bash
aws cloudformation wait stack-create-complete \
  --stack-name awsportfolio-network \
  --region us-east-1
```

#### Step 2: Deploy Microservices (Can be deployed in parallel)

**View Counter Microservice:**
```bash
aws cloudformation create-stack \
  --stack-name awsportfolio-view-counter \
  --template-body file://cloudformation/03-view-counter-microservice.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=AWSPortfolio \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

**Blog Microservice:**
```bash
aws cloudformation create-stack \
  --stack-name awsportfolio-blog \
  --template-body file://cloudformation/04-blog-microservice.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=AWSPortfolio \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

**Contact Form Microservice:**
```bash
aws cloudformation create-stack \
  --stack-name awsportfolio-contact-form \
  --template-body file://cloudformation/05-contact-form-microservice.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=AWSPortfolio \
               ParameterKey=NotificationEmail,ParameterValue=your-email@example.com \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

**AWS News Microservice:**
```bash
aws cloudformation create-stack \
  --stack-name awsportfolio-aws-news \
  --template-body file://cloudformation/06-aws-news-microservice.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=AWSPortfolio \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

#### Step 3: Get Lambda Function URLs

After microservices are deployed, retrieve the Lambda Function URLs:

```bash
# View Counter Function URL
aws cloudformation describe-stacks \
  --stack-name awsportfolio-view-counter \
  --query 'Stacks[0].Outputs[?OutputKey==`ViewsFunctionUrl`].OutputValue' \
  --output text \
  --region us-east-1

# Blog Views Function URL
aws cloudformation describe-stacks \
  --stack-name awsportfolio-blog \
  --query 'Stacks[0].Outputs[?OutputKey==`BlogViewsFunctionUrl`].OutputValue' \
  --output text \
  --region us-east-1

# Contact Form Function URL
aws cloudformation describe-stacks \
  --stack-name awsportfolio-contact-form \
  --query 'Stacks[0].Outputs[?OutputKey==`ContactFormFunctionUrl`].OutputValue' \
  --output text \
  --region us-east-1

# AWS News Function URL
aws cloudformation describe-stacks \
  --stack-name awsportfolio-aws-news \
  --query 'Stacks[0].Outputs[?OutputKey==`UpdateWebpageFunctionUrl`].OutputValue' \
  --output text \
  --region us-east-1
```

#### Step 4: Update Application Code with Function URLs

Update the following files on your EC2 instances or AMI:

- **index.js** (line 3): Add View Counter Function URL
- **index.js** (line 34): Add Contact Form Function URL
- **blog.js** (line 6): Add Blog Views Function URL
- **aws.js** (line 2): Add AWS News Function URL

#### Step 5: Trigger Initial RSS Fetch

Manually invoke the RSS fetch Lambda to populate the DynamoDB table:

```bash
aws lambda invoke \
  --function-name AWSPortfolio-RSSFetchFunction \
  --region us-east-1 \
  response.json
```

#### Step 6: Create Custom AMI (Optional but Recommended)

After updating the application code with Function URLs:

1. Launch an EC2 instance from the base AMI
2. Update the JavaScript files with Function URLs
3. Upload certification images to the website directory
4. Create a new AMI from this instance
5. Update the Compute Stack parameter with your new AMI ID

#### Step 7: Deploy Compute Stack

```bash
aws cloudformation create-stack \
  --stack-name awsportfolio-compute \
  --template-body file://cloudformation/02-compute-stack.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=AWSPortfolio \
               ParameterKey=AMIId,ParameterValue=ami-XXXXXXXXX \
               ParameterKey=InstanceType,ParameterValue=t2.micro \
               ParameterKey=MinSize,ParameterValue=2 \
               ParameterKey=MaxSize,ParameterValue=4 \
               ParameterKey=DesiredCapacity,ParameterValue=2 \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

#### Step 8: Deploy CloudFront and Route53 (Optional)

If you have a custom domain and ACM certificate:

```bash
aws cloudformation create-stack \
  --stack-name awsportfolio-cloudfront \
  --template-body file://cloudformation/07-cloudfront-route53-stack.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=AWSPortfolio \
               ParameterKey=DomainName,ParameterValue=example.com \
               ParameterKey=ACMCertificateArn,ParameterValue=arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT-ID \
               ParameterKey=CreateHostedZone,ParameterValue=false \
               ParameterKey=HostedZoneId,ParameterValue=Z1234567890ABC \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

Without custom domain (CloudFront only):
```bash
aws cloudformation create-stack \
  --stack-name awsportfolio-cloudfront \
  --template-body file://cloudformation/07-cloudfront-route53-stack.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=AWSPortfolio \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

#### Step 9: Get Website URL

```bash
# Get ALB DNS (if not using CloudFront)
aws cloudformation describe-stacks \
  --stack-name awsportfolio-compute \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text \
  --region us-east-1

# Get CloudFront URL
aws cloudformation describe-stacks \
  --stack-name awsportfolio-cloudfront \
  --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' \
  --output text \
  --region us-east-1
```

### Stage 2: Serverless Migration

#### Step 10: Deploy S3 Static Website Stack

```bash
aws cloudformation create-stack \
  --stack-name awsportfolio-static-website \
  --template-body file://cloudformation/08-s3-static-website-stack.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=AWSPortfolio \
               ParameterKey=DomainName,ParameterValue=example.com \
               ParameterKey=HostedZoneId,ParameterValue=Z1234567890ABC \
               ParameterKey=ACMCertificateArn,ParameterValue=arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT-ID \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

#### Step 11: Upload Website Files to S3

```bash
# Get bucket name
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name awsportfolio-static-website \
  --query 'Stacks[0].Outputs[?OutputKey==`WebsiteBucketName`].OutputValue' \
  --output text \
  --region us-east-1)

# Upload files
aws s3 sync ./website s3://${BUCKET_NAME}/ --delete --region us-east-1
```

#### Step 12: Invalidate CloudFront Cache

```bash
DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
  --stack-name awsportfolio-static-website \
  --query 'Stacks[0].Outputs[?OutputKey==`StaticWebsiteDistributionId`].OutputValue' \
  --output text \
  --region us-east-1)

aws cloudfront create-invalidation \
  --distribution-id ${DISTRIBUTION_ID} \
  --paths "/*" \
  --region us-east-1
```

#### Step 13: Update Route53 Records (if needed)

Update your Route53 records to point to the new static website CloudFront distribution instead of the ALB-based CloudFront distribution.

#### Step 14: Clean Up Server-Based Resources (Optional)

Once you've verified the static website works correctly, you can delete the server-based compute resources:

```bash
# Delete compute stack (EC2, ASG, ALB)
aws cloudformation delete-stack \
  --stack-name awsportfolio-compute \
  --region us-east-1

# Optionally delete the original CloudFront stack
aws cloudformation delete-stack \
  --stack-name awsportfolio-cloudfront \
  --region us-east-1
```

## Stack Dependencies

```
Network Stack (01)
    ↓
Compute Stack (02) ← Requires Network Stack outputs
    ↓
CloudFront Stack (07) ← Requires Compute Stack (ALB DNS)

Microservices (03, 04, 05, 06) - Independent, no dependencies
    ↓
Update EC2 application code with Lambda URLs
    ↓
Static Website Stack (08) - Independent, for Stage 2 migration
```

## Configuration Files Structure

```
cloudformation/
├── 01-network-stack.yaml              # VPC, Subnets, NAT, Security Groups
├── 02-compute-stack.yaml              # ALB, ASG, EC2, Launch Template
├── 03-view-counter-microservice.yaml  # Lambda + DynamoDB for view counts
├── 04-blog-microservice.yaml          # S3 + Lambda + DynamoDB for blog
├── 05-contact-form-microservice.yaml  # Lambda + SNS + DynamoDB for contact
├── 06-aws-news-microservice.yaml      # Lambda + EventBridge + DynamoDB for news
├── 07-cloudfront-route53-stack.yaml   # CloudFront + Route53 for Stage 1
└── 08-s3-static-website-stack.yaml    # S3 + CloudFront for Stage 2
```

## Resource Naming Convention

All resources use the pattern: `${EnvironmentName}-<ResourceType>`

Example: `AWSPortfolio-VPC`, `AWSPortfolio-ALB`, `AWSPortfolio-ViewsFunction`

## Exported Values

Each stack exports values that can be imported by other stacks using `Fn::ImportValue`. Key exports include:

- Network: VPC ID, Subnet IDs, Security Group IDs
- Compute: ALB DNS, Target Group ARN
- Microservices: Lambda Function URLs, DynamoDB Table Names
- CloudFront: Distribution IDs, Website URLs

## Cost Optimization Tips

1. **Use t2.micro or t3.micro** instances for development/testing
2. **Adjust Auto Scaling Group size** based on traffic patterns
3. **Use S3 Intelligent-Tiering** for static assets
4. **Enable CloudFront caching** to reduce origin requests
5. **Use DynamoDB on-demand billing** for unpredictable workloads
6. **Migrate to Stage 2 (static website)** to eliminate EC2 costs

## Security Best Practices Implemented

- ✅ EC2 instances in private subnets (no public IPs)
- ✅ Traffic flows through ALB in public subnets
- ✅ Security Groups with principle of least privilege
- ✅ S3 buckets with encryption enabled
- ✅ DynamoDB tables with encryption at rest
- ✅ IAM roles with minimal required permissions
- ✅ CloudFront with HTTPS redirect
- ✅ Lambda Function URLs with CORS configuration

## Monitoring and Logging

All Lambda functions automatically log to CloudWatch Logs. To view logs:

```bash
aws logs tail /aws/lambda/AWSPortfolio-ViewsFunction --follow --region us-east-1
```

## Troubleshooting

### Issue: Lambda Function URLs not working
- Check CORS configuration is enabled (all headers, methods, origins)
- Verify Lambda has correct IAM permissions
- Check Lambda function logs in CloudWatch

### Issue: EC2 instances not healthy in ALB
- Verify Security Group allows traffic from ALB
- Check application is running on port 80
- Review ALB target group health check settings

### Issue: CloudFront not serving content
- Wait for distribution to fully deploy (can take 15-20 minutes)
- Check origin configuration matches ALB DNS or S3 bucket
- Verify ACM certificate is in us-east-1 region

### Issue: Blog posts not appearing
- Ensure S3 bucket has event notification configured for Lambda
- Check .txt files are being uploaded to correct S3 bucket
- Verify CreatePostFunction has permissions to read S3 and write to DynamoDB

## Updating Stacks

To update an existing stack:

```bash
aws cloudformation update-stack \
  --stack-name awsportfolio-<stack-name> \
  --template-body file://cloudformation/<template-file>.yaml \
  --parameters <parameters> \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## Deleting Stacks

Delete stacks in reverse order of creation:

```bash
# Stage 2 (if deployed)
aws cloudformation delete-stack --stack-name awsportfolio-static-website --region us-east-1

# Stage 1
aws cloudformation delete-stack --stack-name awsportfolio-cloudfront --region us-east-1
aws cloudformation delete-stack --stack-name awsportfolio-compute --region us-east-1

# Microservices (can be deleted in any order)
aws cloudformation delete-stack --stack-name awsportfolio-aws-news --region us-east-1
aws cloudformation delete-stack --stack-name awsportfolio-contact-form --region us-east-1
aws cloudformation delete-stack --stack-name awsportfolio-blog --region us-east-1
aws cloudformation delete-stack --stack-name awsportfolio-view-counter --region us-east-1

# Network (delete last)
aws cloudformation delete-stack --stack-name awsportfolio-network --region us-east-1
```

**Note:** S3 buckets with content may need to be emptied before stack deletion succeeds.

## Support

For issues or questions:
1. Check CloudFormation stack events for error messages
2. Review CloudWatch Logs for Lambda functions
3. Verify all prerequisites are met
4. Ensure you're deploying in the us-east-1 region

## License

This project is provided as-is for educational purposes.
