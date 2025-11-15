# NAT Instance Migration Guide

## Overview

This document explains the migration from **NAT Gateways** to **NAT Instances** to reduce AWS costs by approximately **$58/month** (~90% savings on NAT costs).

## Cost Comparison

### Before: NAT Gateways
```
NAT Gateway 1 (AZ1):        $32.85/month
NAT Gateway 2 (AZ2):        $32.85/month
Data Processing:            ~$0.045/GB
─────────────────────────────────────
Total NAT Cost:             ~$65.70/month
```

### After: NAT Instances
```
t3.nano Instance 1 (AZ1):   $3.50/month
t3.nano Instance 2 (AZ2):   $3.50/month
Elastic IP 1:               $0.00 (attached)
Elastic IP 2:               $0.00 (attached)
Data Transfer:              Standard EC2 rates
─────────────────────────────────────
Total NAT Cost:             ~$7.00/month

SAVINGS:                    ~$58.70/month (89% reduction)
```

## What Changed in the Network Stack

### 1. Removed Resources
- ❌ `NatGateway1` - Removed
- ❌ `NatGateway2` - Removed
- ❌ `NatGateway1EIP` - Removed (was for NAT Gateway)
- ❌ `NatGateway2EIP` - Removed (was for NAT Gateway)

### 2. Added Resources
- ✅ `NATInstanceSecurityGroup` - Security group for NAT instances
- ✅ `NATInstance1` - t3.nano EC2 instance in Public Subnet 1
- ✅ `NATInstance2` - t3.nano EC2 instance in Public Subnet 2
- ✅ `NATInstance1EIP` - Elastic IP for NAT Instance 1
- ✅ `NATInstance2EIP` - Elastic IP for NAT Instance 2

### 3. Modified Resources
- 🔄 `DefaultPrivateRoute1` - Now routes to `NATInstance1` instead of `NatGateway1`
- 🔄 `DefaultPrivateRoute2` - Now routes to `NATInstance2` instead of `NatGateway2`

## NAT Instance Configuration

### Instance Type: t3.nano
- **vCPUs:** 2
- **Memory:** 0.5 GB
- **Network:** Up to 5 Gbps
- **Cost:** $3.50/month (on-demand)
- **Sufficient for:** Low to moderate traffic websites

### AMI Selection
Uses AWS Systems Manager Parameter Store to get the latest Amazon Linux 2 AMI:
```yaml
ImageId: !Sub '{{resolve:ssm:/aws/service/ami-amazon-linux-latest/amzn2-ami-kernel-5.10-hvm-x86_64-gp2}}'
```

### Critical Configuration
```yaml
SourceDestCheck: false  # Required for NAT functionality
```
**Why:** Allows the instance to forward traffic that's not destined for itself.

### UserData Script
The NAT instances are automatically configured with:

```bash
#!/bin/bash
# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Install and configure iptables
yum install -y iptables-services
systemctl enable iptables
systemctl start iptables

# Setup NAT rules
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -F FORWARD
service iptables save
```

**What this does:**
1. Enables IP forwarding at the kernel level
2. Installs iptables for network address translation
3. Configures MASQUERADE rule for outbound traffic
4. Saves the configuration to survive reboots

## Security Group Configuration

### NAT Instance Security Group
```yaml
Ingress Rules:
- HTTP (80) from VPC (10.0.0.0/16)
- HTTPS (443) from VPC (10.0.0.0/16)
- ICMP (all) from VPC (10.0.0.0/16)

Egress Rules:
- All traffic to Internet (0.0.0.0/0)
```

**Security Notes:**
- Only accepts traffic from within the VPC
- Cannot be accessed directly from the internet
- Private subnet instances route through these NAT instances

## Architecture Diagram

### Before (NAT Gateways)
```
┌─────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                    │
│                                                         │
│  ┌──────────────────┐        ┌──────────────────┐     │
│  │  Public Subnet 1 │        │  Public Subnet 2 │     │
│  │                  │        │                  │     │
│  │  ┌────────────┐  │        │  ┌────────────┐  │     │
│  │  │ NAT GW 1   │  │        │  │ NAT GW 2   │  │     │
│  │  │ $32.85/mo  │  │        │  │ $32.85/mo  │  │     │
│  │  └────────────┘  │        │  └────────────┘  │     │
│  └──────────────────┘        └──────────────────┘     │
│         ↑                            ↑                 │
│         │                            │                 │
│  ┌──────────────────┐        ┌──────────────────┐     │
│  │ Private Subnet 1 │        │ Private Subnet 2 │     │
│  │  (Web Servers)   │        │  (Web Servers)   │     │
│  └──────────────────┘        └──────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### After (NAT Instances)
```
┌─────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                    │
│                                                         │
│  ┌──────────────────┐        ┌──────────────────┐     │
│  │  Public Subnet 1 │        │  Public Subnet 2 │     │
│  │                  │        │                  │     │
│  │  ┌────────────┐  │        │  ┌────────────┐  │     │
│  │  │NAT Instance│  │        │  │NAT Instance│  │     │
│  │  │  t3.nano   │  │        │  │  t3.nano   │  │     │
│  │  │ $3.50/mo   │  │        │  │ $3.50/mo   │  │     │
│  │  └────────────┘  │        │  └────────────┘  │     │
│  └──────────────────┘        └──────────────────┘     │
│         ↑                            ↑                 │
│         │                            │                 │
│  ┌──────────────────┐        ┌──────────────────┐     │
│  │ Private Subnet 1 │        │ Private Subnet 2 │     │
│  │  (Web Servers)   │        │  (Web Servers)   │     │
│  └──────────────────┘        └──────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

## Traffic Flow

```
Private EC2 Instance
        ↓
  (Needs to reach internet)
        ↓
  Route Table: 0.0.0.0/0 → NAT Instance
        ↓
  NAT Instance (in public subnet)
        ↓
  iptables MASQUERADE (changes source IP)
        ↓
  Internet Gateway
        ↓
  Internet
```

## Deployment

### New Deployment
If deploying for the first time:
```bash
aws cloudformation create-stack \
  --stack-name awsportfolio-network \
  --template-body file://01-network-stack.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=AWSPortfolio \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### Updating Existing Stack
⚠️ **Warning:** This will cause brief downtime as NAT Gateways are replaced with NAT Instances.

```bash
# Update the stack
aws cloudformation update-stack \
  --stack-name awsportfolio-network \
  --template-body file://01-network-stack.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=AWSPortfolio \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Monitor the update
aws cloudformation wait stack-update-complete \
  --stack-name awsportfolio-network \
  --region us-east-1
```

**Expected Downtime:** 
- NAT Gateway deletion: ~1-2 minutes
- NAT Instance creation: ~2-3 minutes
- Route table updates: ~30 seconds
- **Total:** Approximately 3-5 minutes

## Trade-offs

### Pros ✅
- **Cost Savings:** ~$58/month reduction (89% savings)
- **Same Functionality:** Private instances can still reach the internet
- **Multi-AZ Redundancy:** Still have NAT in each AZ
- **Auto-configured:** UserData script handles all NAT setup
- **Latest AMI:** Uses AWS-maintained Amazon Linux 2

### Cons ⚠️
- **Management Overhead:** Need to patch/update NAT instances
- **Single Point of Failure:** Each NAT instance is a single EC2 instance
- **Lower Throughput:** t3.nano has lower network performance than NAT Gateway
- **Manual Scaling:** Cannot auto-scale like NAT Gateway
- **Availability:** If NAT instance fails, need to manually replace or use ASG

## Performance Comparison

| Metric | NAT Gateway | NAT Instance (t3.nano) |
|--------|-------------|------------------------|
| Bandwidth | Up to 100 Gbps | Up to 5 Gbps |
| Connections | Unlimited | ~55,000 concurrent |
| Availability | 99.99% SLA | Single instance (no SLA) |
| Scaling | Automatic | Manual |
| Management | Fully managed | Self-managed |
| Cost | $32.85/month | $3.50/month |

## Monitoring NAT Instances

### Check NAT Instance Status
```bash
# Get instance IDs
aws cloudformation describe-stacks \
  --stack-name awsportfolio-network \
  --query 'Stacks[0].Outputs[?OutputKey==`NATInstance1Id`].OutputValue' \
  --output text

# Check instance status
aws ec2 describe-instances \
  --instance-ids <INSTANCE-ID> \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text
```

### Verify NAT Functionality
From a private subnet instance:
```bash
# Test internet connectivity
ping -c 4 8.8.8.8

# Test DNS resolution
curl -I https://www.amazon.com

# Check routing
traceroute 8.8.8.8
```

### View NAT Instance Logs
```bash
# SSH into NAT instance (requires bastion or Session Manager)
sudo tail -f /var/log/nat-startup.log

# Check iptables rules
sudo iptables -t nat -L -n -v
```

## High Availability Enhancement (Optional)

For production, consider adding Auto Scaling for NAT instances:

```yaml
# Add this to make NAT instances highly available
NATInstanceAutoRecovery1:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmDescription: Recover NAT Instance 1 on failure
    MetricName: StatusCheckFailed_System
    Namespace: AWS/EC2
    Statistic: Maximum
    Period: 60
    EvaluationPeriods: 2
    Threshold: 1
    AlarmActions:
      - !Sub 'arn:aws:automate:${AWS::Region}:ec2:recover'
    Dimensions:
      - Name: InstanceId
        Value: !Ref NATInstance1
```

## Troubleshooting

### Issue: Private instances cannot reach internet

**Check 1:** Verify SourceDestCheck is disabled
```bash
aws ec2 describe-instance-attribute \
  --instance-id <NAT-INSTANCE-ID> \
  --attribute sourceDestCheck
# Should return: "SourceDestCheck": {"Value": false}
```

**Check 2:** Verify IP forwarding is enabled
```bash
# On NAT instance
sysctl net.ipv4.ip_forward
# Should return: net.ipv4.ip_forward = 1
```

**Check 3:** Verify iptables rules
```bash
# On NAT instance
sudo iptables -t nat -L POSTROUTING -n -v
# Should show MASQUERADE rule
```

**Check 4:** Verify route table
```bash
aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=AWSPortfolio-Private-Routes-AZ1" \
  --query 'RouteTables[0].Routes'
# Should show route to NAT instance
```

### Issue: NAT instance not starting

**Solution:** Check CloudFormation events
```bash
aws cloudformation describe-stack-events \
  --stack-name awsportfolio-network \
  --max-items 20
```

### Issue: High latency through NAT

**Solution:** Consider upgrading to larger instance type
```yaml
InstanceType: t3.small  # or t3.medium for higher traffic
```

## Cost Optimization Tips

1. **Use t4g.nano (ARM)** - Even cheaper at $2.52/month
2. **Reserved Instances** - Save 40-50% with 1-year commitment
3. **Single NAT Instance** - Use one NAT for both AZs (save another $3.50/mo)
4. **Scheduled Scaling** - Stop NAT instances during off-hours (dev/test only)

## Reverting to NAT Gateways

If you need to revert back to NAT Gateways:

1. Keep a copy of the original template
2. Update the stack with the original template
3. CloudFormation will automatically:
   - Delete NAT instances
   - Create NAT Gateways
   - Update route tables

```bash
# Revert to NAT Gateways
aws cloudformation update-stack \
  --stack-name awsportfolio-network \
  --template-body file://01-network-stack-original.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=AWSPortfolio \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## Monthly Cost Summary

### Total Infrastructure Costs

**Before (with NAT Gateways):**
```
EC2 Instances (2x t2.micro):    $17.00/month
NAT Gateways (2):               $65.70/month
Application Load Balancer:      $20.00/month
EBS Volumes:                    $2.00/month
Data Transfer:                  $5.00/month
───────────────────────────────────────────
Total:                          $109.70/month
```

**After (with NAT Instances):**
```
EC2 Instances (2x t2.micro):    $17.00/month
NAT Instances (2x t3.nano):     $7.00/month   ⬅️ REDUCED
Application Load Balancer:      $20.00/month
EBS Volumes:                    $2.00/month
Data Transfer:                  $5.00/month
───────────────────────────────────────────
Total:                          $51.00/month

💰 SAVINGS: $58.70/month (53% reduction)
💰 ANNUAL SAVINGS: $704.40/year
```

## Conclusion

Switching from NAT Gateways to NAT Instances provides significant cost savings for low to moderate traffic websites. While there are trade-offs in terms of management and potential performance, for a portfolio website or learning project, NAT instances are an excellent choice.

**Best for:**
- ✅ Portfolio websites
- ✅ Development/testing environments
- ✅ Low traffic applications
- ✅ Cost-conscious deployments
- ✅ Learning AWS networking

**Not recommended for:**
- ❌ High-traffic production applications
- ❌ Mission-critical workloads requiring 99.99% SLA
- ❌ Applications needing > 5 Gbps bandwidth
- ❌ Environments with no operational staff
