#!/bin/bash

################################################################################
# Script: setup.sh
# Purpose: Setup and verify environment for AWS automation scripts
# Author: DevOps Automation Lab
# Date: December 23, 2025
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}AWS Automation Lab - Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Check if AWS CLI is installed
print_info "Checking for AWS CLI..."
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1)
    print_success "AWS CLI is installed: $AWS_VERSION"
else
    print_error "AWS CLI is not installed"
    echo ""
    echo "Please install AWS CLI:"
    echo "  Linux: curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' && unzip awscliv2.zip && sudo ./aws/install"
    echo "  macOS: brew install awscli"
    echo ""
    exit 1
fi

echo ""

# Check AWS credentials
print_info "Checking AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    print_success "AWS credentials are configured"
    echo ""
    aws sts get-caller-identity | while IFS= read -r line; do
        echo "  $line"
    done
else
    print_error "AWS credentials are not configured"
    echo ""
    echo "Please configure AWS CLI:"
    echo "  aws configure"
    echo ""
    echo "You will need:"
    echo "  - AWS Access Key ID"
    echo "  - AWS Secret Access Key"
    echo "  - Default region (e.g., us-east-1)"
    echo ""
    exit 1
fi

echo ""

# Check AWS region
print_info "Checking AWS region configuration..."
REGION=$(aws configure get region)
if [ -n "$REGION" ]; then
    print_success "Default region is set to: $REGION"
else
    print_error "No default region configured"
    echo "Please set a default region: aws configure set region us-east-1"
    exit 1
fi

echo ""

# Make scripts executable
print_info "Making scripts executable..."
chmod +x create_ec2.sh
chmod +x create_security_group.sh
chmod +x create_s3_bucket.sh
chmod +x cleanup_resources.sh
print_success "All scripts are now executable"

echo ""

# Check for required permissions (basic test)
print_info "Testing AWS permissions..."

# Test EC2 permissions
if aws ec2 describe-vpcs --region "$REGION" &> /dev/null; then
    print_success "EC2 permissions verified"
else
    print_error "EC2 permissions issue - check IAM policies"
fi

# Test S3 permissions
if aws s3 ls &> /dev/null; then
    print_success "S3 permissions verified"
else
    print_error "S3 permissions issue - check IAM policies"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Available scripts:${NC}"
echo -e "  1. ${GREEN}./create_ec2.sh${NC}             - Create EC2 instance"
echo -e "  2. ${GREEN}./create_security_group.sh${NC}  - Create security group"
echo -e "  3. ${GREEN}./create_s3_bucket.sh${NC}       - Create S3 bucket"
echo -e "  4. ${GREEN}./cleanup_resources.sh${NC}      - Cleanup all resources"
echo ""
echo -e "${YELLOW}Quick start:${NC}"
echo -e "  ./create_security_group.sh    # Create security group first"
echo -e "  ./create_ec2.sh                # Create EC2 instance"
echo -e "  ./create_s3_bucket.sh          # Create S3 bucket"
echo -e "  ./cleanup_resources.sh         # Cleanup when done"
echo ""
echo -e "${BLUE}For more information, see README.md${NC}"
echo ""
