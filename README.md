# Portfolio_Solutions_Architect

As I progress in my journey toward becoming an AWS Machine Learning Specialist, I'm proud to have successfully earned the **AWS Solutions Architect Associate** certification.

This repository is a showcase of my projects as a Solutions Architect Associate, where I highlight my expertise in AWS services through Infrastructure as Code (IaC), architecture design, and cloud solutions. My goal is to share knowledge, document my learning path, and contribute valuable content to the community.

##  Project Overview

This repository contains a **production-ready AWS portfolio website** with a complete CloudFormation Infrastructure as Code (IaC) implementation. The project demonstrates advanced AWS architectural patterns, cost optimization strategies, and best practices for building scalable, secure cloud applications.

##  What I've Built

### Complete CloudFormation Stack Suite (8 Stacks)

I've designed and implemented a comprehensive multi-tier AWS architecture using CloudFormation, organized into 8 logical stacks:

#### **Stage 1: Server-Based Architecture**
1. ✅ **Network Stack** (`01-network-stack.yaml`)
   - Multi-AZ VPC with public and private subnets
   - **Cost-optimized NAT Instances** (migrated from NAT Gateways)
   - Security Groups with least privilege access
   - Internet Gateway and route tables
   - **Achieved 89% cost reduction on NAT infrastructure**

2. ✅ **Compute Stack** (`02-compute-stack.yaml`)
   - Application Load Balancer for high availability
   - Auto Scaling Group with dynamic scaling
   - Launch Template with custom AMI
   - EC2 instances in private subnets (no public IPs)
   - Target Groups with health checks

3. ✅ **View Counter Microservice** (`03-view-counter-microservice.yaml`)
   - Lambda function with Function URL
   - DynamoDB table for persistent view counts
   - CORS-enabled for cross-origin requests
   - CloudWatch logging

4. ✅ **Blog Microservice** (`04-blog-microservice.yaml`)
   - S3 bucket for blog post uploads
   - Lambda functions for post creation and retrieval
   - DynamoDB for blog data and view tracking
   - Event-driven architecture with S3 triggers

5. ✅ **Contact Form Microservice** (`05-contact-form-microservice.yaml`)
   - Lambda function for form processing
   - SNS topic for email notifications
   - DynamoDB for submission tracking
   - Email confirmation workflow

6. ✅ **AWS News Microservice** (`06-aws-news-microservice.yaml`)
   - RSS feed parser with EventBridge scheduling
   - Daily automated news fetching (9 AM UTC)
   - DynamoDB for news storage
   - Lambda Function URLs for webpage integration

7. ✅ **CloudFront & Route53 Stack** (`07-cloudfront-route53-stack.yaml`)
   - Global content delivery with CloudFront
   - Custom domain configuration with Route53
   - HTTPS with ACM certificate integration
   - Cache optimization for static assets

#### **Stage 2: Serverless Migration**
8. ✅ **S3 Static Website Stack** (`08-s3-static-website-stack.yaml`)
   - Fully serverless static website hosting
   - CloudFront distribution with Origin Access Control
   - S3 bucket with encryption and versioning
   - **Reduces costs by ~95%** compared to server-based approach

###  Architecture Workflow

#### **Stage 1: Server-Based Architecture Flow**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              USER REQUEST                                │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         Route 53 (DNS Resolution)                        │
│                         example.com → CloudFront                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                    CloudFront Distribution (CDN)                         │
│                    - HTTPS Termination (ACM Certificate)                 │
│                    - Cache static assets (CSS, JS, images)               │
│                    - Forward dynamic requests to ALB                     │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                    Application Load Balancer (ALB)                       │
│                    - Public Subnets (Multi-AZ)                           │
│                    - Health checks on EC2 targets                        │
│                    - Distributes traffic across AZs                      │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
                    ┌───────────────┴───────────────┐
                    ↓                               ↓
        ┌─────────────────────┐       ┌─────────────────────┐
        │  EC2 Instance (AZ-A) │       │  EC2 Instance (AZ-B) │
        │  Private Subnet      │       │  Private Subnet      │
        │  - Apache Web Server │       │  - Apache Web Server │
        │  - Portfolio Website │       │  - Portfolio Website │
        │  - No Public IP      │       │  - No Public IP      │
        └─────────────────────┘       └─────────────────────┘
                    ↓                               ↓
        ┌─────────────────────┐       ┌─────────────────────┐
        │  NAT Instance (AZ-A) │       │  NAT Instance (AZ-B) │
        │  t3.nano             │       │  t3.nano             │
        └─────────────────────┘       └─────────────────────┘
                    ↓                               ↓
                    └───────────────┬───────────────┘
                                    ↓
                        ┌───────────────────┐
                        │  Internet Gateway  │
                        └───────────────────┘
                                    ↓
        ┌───────────────────────────┼───────────────────────────┐
        ↓                           ↓                           ↓
┌───────────────┐         ┌───────────────┐         ┌───────────────┐
│ View Counter  │         │  Blog Posts   │         │ Contact Form  │
│   Lambda      │         │   Lambda      │         │   Lambda      │
│      ↕        │         │      ↕        │         │      ↕        │
│  DynamoDB     │         │  DynamoDB     │         │  DynamoDB     │
└───────────────┘         │      ↕        │         │      ↕        │
                          │  S3 Bucket    │         │  SNS Topic    │
                          └───────────────┘         └───────────────┘
                                                             ↓
                          ┌───────────────┐         ┌───────────────┐
                          │  AWS News     │         │ Email to Admin│
                          │   Lambda      │         └───────────────┘
                          │      ↕        │
                          │  DynamoDB     │
                          │      ↕        │
                          │ EventBridge   │
                          │ (Daily 9 AM)  │
                          └───────────────┘
```

#### **Stage 2: Serverless Architecture Flow**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              USER REQUEST                                │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         Route 53 (DNS Resolution)                        │
│                         example.com → CloudFront                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                    CloudFront Distribution (CDN)                         │
│                    - HTTPS Termination (ACM Certificate)                 │
│                    - Cache ALL static content                            │
│                    - Origin Access Control to S3                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                        S3 Bucket (Private)                               │
│                    - Static Website Files                                │
│                    - Encryption Enabled                                  │
│                    - Versioning Enabled                                  │
│                    - No Public Access                                    │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
        ┌───────────────────────────┼───────────────────────────┐
        ↓                           ↓                           ↓
┌───────────────┐         ┌───────────────┐         ┌───────────────┐
│ View Counter  │         │  Blog Posts   │         │ Contact Form  │
│Lambda Fn URL  │         │Lambda Fn URL  │         │Lambda Fn URL  │
│      ↕        │         │      ↕        │         │      ↕        │
│  DynamoDB     │         │  DynamoDB     │         │  DynamoDB     │
└───────────────┘         │      ↕        │         │      ↕        │
                          │  S3 Bucket    │         │  SNS Topic    │
                          └───────────────┘         └───────────────┘
                                                             ↓
                          ┌───────────────┐         ┌───────────────┐
                          │  AWS News     │         │ Email to Admin│
                          │Lambda Fn URL  │         └───────────────┘
                          │      ↕        │
                          │  DynamoDB     │
                          │      ↕        │
                          │ EventBridge   │
                          │ (Daily 9 AM)  │
                          └───────────────┘

 Key Difference: No EC2, ALB, or NAT instances = 95% cost reduction
```

#### **Detailed Request Flow by Feature**

**1. Page View Counter**
```
User visits page → JavaScript fetch() → Lambda Function URL
                                              ↓
                                    Increment counter in DynamoDB
                                              ↓
                                    Return updated count
                                              ↓
                                    Display on webpage
```

**2. Blog Post System**
```
Admin Upload:
Admin uploads .txt file → S3 Bucket → S3 Event Notification
                                              ↓
                                    Lambda (CreatePostFunction)
                                              ↓
                                    Parse and store in DynamoDB

User View:
User visits blog page → JavaScript fetch() → Lambda Function URL
                                              ↓
                                    Query DynamoDB for posts
                                              ↓
                                    Return post list with view counts
                                              ↓
                                    Display posts on webpage
```

**3. Contact Form**
```
User submits form → JavaScript fetch() → Lambda Function URL
                                              ↓
                               ┌──────────────┴──────────────┐
                               ↓                             ↓
                    Store in DynamoDB              Publish to SNS Topic
                    (Submissions table)                      ↓
                               ↓                    Send email to admin
                    Return success message                   ↓
                               ↓                    Email confirmation sent
                    Display confirmation
```

**4. AWS News Feed**
```
Automated Process (Daily):
EventBridge Rule (9 AM UTC) → Lambda (RSSFetchFunction)
                                              ↓
                                    Fetch AWS RSS feed
                                              ↓
                                    Parse XML content
                                              ↓
                                    Store in DynamoDB (AWSNews table)

User View:
User visits AWS news section → JavaScript fetch() → Lambda Function URL
                                                          ↓
                                                Query DynamoDB for latest news
                                                          ↓
                                                Return news items
                                                          ↓
                                                Display on webpage
```

#### **Security Flow**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SECURITY LAYERS                                  │
└─────────────────────────────────────────────────────────────────────────┘

Layer 1: Network Security
├── Internet Gateway (Controlled entry point)
├── Public Subnets (Only ALB and NAT instances)
├── Private Subnets (EC2 instances, no public IPs)
└── Security Groups (Least privilege rules)

Layer 2: Application Security
├── CloudFront (DDoS protection, TLS 1.2+)
├── ALB (SSL/TLS termination, health checks)
├── Lambda Function URLs (CORS configured)
└── WAF (Optional - can be added)

Layer 3: Data Security
├── S3 Encryption (AES-256 at rest)
├── DynamoDB Encryption (At rest enabled)
├── SNS Encryption (In transit)
└── CloudWatch Logs (Encrypted)

Layer 4: Access Control
├── IAM Roles (Least privilege per service)
├── S3 Bucket Policies (Block public access)
├── CloudFront OAC (S3 origin access control)
└── Security Groups (Port-specific rules)
```

###  Architecture Highlights

- **High Availability**: Multi-AZ deployment across 2 availability zones
- **Security Best Practices**: 
  - EC2 instances in private subnets with no direct internet access
  - Security Groups implementing principle of least privilege
  - Encryption at rest for S3 and DynamoDB
  - IAM roles with minimal required permissions
- **Cost Optimization**:
  - NAT Instance migration saving ~$59/month (89% reduction)
  - Serverless microservices reducing compute costs
  - Optional Stage 2 migration for 95% total cost reduction
- **Scalability**: Auto Scaling Groups with configurable min/max capacity
- **Event-Driven**: S3 triggers, EventBridge scheduling, SNS notifications
- **Monitoring**: CloudWatch Logs integration for all Lambda functions

## 📊 Cost Analysis

### Server-Based Architecture (Stage 1)
- **Before Optimization**: ~$110/month
- **After NAT Instance Migration**: ~$51/month
- **Savings**: $59/month (54% reduction)

### Serverless Architecture (Stage 2)
- **Total Cost**: ~$2-5/month
- **Savings from Stage 1**: ~$46-49/month (95% reduction)

**Annual savings with full serverless migration: ~$600-700/year**

##  Technical Documentation

I've created comprehensive documentation including:

- **[ARCHITECTURE.md](portfolio_website_cloudformation_stacks/ARCHITECTURE.md)** - Detailed architecture diagrams with network flow, stack dependencies, and deployment timeline
- **[NAT-INSTANCE-MIGRATION.md](portfolio_website_cloudformation_stacks/NAT-INSTANCE-MIGRATION.md)** - Complete guide on cost optimization strategy, trade-offs, and migration process
- **[README.md](portfolio_website_cloudformation_stacks/README.md)** - Deployment instructions, troubleshooting guide, and operational procedures

##  Key Skills Demonstrated

- **Infrastructure as Code (IaC)**: CloudFormation templates with parameters, outputs, and cross-stack references
- **AWS Services**: VPC, EC2, ALB, Auto Scaling, Lambda, DynamoDB, S3, CloudFront, Route53, SNS, EventBridge, IAM, CloudWatch
- **Network Architecture**: Multi-AZ VPC design, public/private subnet segmentation, NAT configuration
- **Security**: Zero-trust network design, IAM policies, Security Groups, encryption
- **Serverless**: Lambda functions, event-driven architecture, Function URLs
- **DevOps**: Deployment automation, monitoring, logging, troubleshooting
- **Cost Optimization**: Resource right-sizing, serverless migration, NAT Gateway alternatives

##  Repository Structure

```
Portfolio_Solutions_Architect/
├── README.md (This file)
├── About_me.pdf
├── three-tier-app.drawio (1).svg
└── portfolio_website_cloudformation_stacks/
    ├── 01-network-stack.yaml
    ├── 02-compute-stack.yaml
    ├── 03-view-counter-microservice.yaml
    ├── 04-blog-microservice.yaml
    ├── 05-contact-form-microservice.yaml
    ├── 06-aws-news-microservice.yaml
    ├── 07-cloudfront-route53-stack.yaml
    ├── 08-s3-static-website-stack.yaml
    ├── ARCHITECTURE.md
    ├── NAT-INSTANCE-MIGRATION.md
    ├── README.md
    ├── deploy.sh
    ├── deploy-static-website.sh
    └── parameters/
        ├── 01-network-params.json
        └── 02-compute-params.json
```

##  Learning Journey

This project represents my practical application of AWS Solutions Architect Associate concepts including:

- ✅ Designing resilient architectures
- ✅ Designing high-performing architectures
- ✅ Designing secure applications and architectures
- ✅ Designing cost-optimized architectures

##  Current Status

**All 8 CloudFormation stacks are complete and fully documented**, ready for deployment. The project demonstrates a complete evolution from a traditional server-based architecture to a modern serverless approach, with detailed migration guides and cost analysis.

##  Next Steps

- Deploying the infrastructure to AWS
- Creating blog content showcasing AWS architecture patterns
- Adding monitoring dashboards and alerts
- Documenting lessons learned and best practices

---

To those who stop by, thank you for visiting my GitHub—I appreciate your time and interest! Feel free to explore the code, review the architecture, and reach out if you have questions or suggestions.
 

 
