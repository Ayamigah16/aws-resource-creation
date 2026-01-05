#!/bin/bash

################################################################################
# Script: project_info.sh
# Purpose: Display project information and quick start guide
# Author: DevOps Automation Lab
# Date: December 23, 2025
################################################################################

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     AWS Resource Creation Automation Project                 ║
║     ========================================                  ║
║                                                               ║
║     Automate EC2, Security Groups & S3 with Bash             ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}📁 Project Structure:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
tree -L 1 --dirsfirst 2>/dev/null || ls -1
echo ""

echo -e "${CYAN}🚀 Quick Start Guide:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}1.${NC} Verify environment:"
echo -e "   ${YELLOW}./setup.sh${NC}"
echo ""
echo -e "${GREEN}2.${NC} Create resources:"
echo -e "   ${YELLOW}./create_security_group.sh${NC}    # Create security group"
echo -e "   ${YELLOW}./create_ec2.sh${NC}                # Create EC2 instance"
echo -e "   ${YELLOW}./create_s3_bucket.sh${NC}          # Create S3 bucket"
echo ""
echo -e "${GREEN}3.${NC} Cleanup resources:"
echo -e "   ${YELLOW}./cleanup_resources.sh --dry-run${NC}   # Preview deletion"
echo -e "   ${YELLOW}./cleanup_resources.sh${NC}             # Actual cleanup"
echo ""

echo -e "${CYAN}📜 Available Scripts:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}setup.sh${NC}"
echo "  → Verify AWS CLI, credentials, and permissions"
echo ""
echo -e "${GREEN}create_ec2.sh${NC}"
echo "  → Create EC2 instance with key pair"
echo "  → Auto-fetch latest Amazon Linux 2 AMI"
echo "  → Tag with Project=AutomationLab"
echo "  → Output: Instance ID, Public IP, SSH command"
echo ""
echo -e "${GREEN}create_security_group.sh${NC}"
echo "  → Create security group in default VPC"
echo "  → Open ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)"
echo "  → Tag with Project=AutomationLab"
echo "  → Output: Security group ID and rules"
echo ""
echo -e "${GREEN}create_s3_bucket.sh${NC}"
echo "  → Create uniquely named S3 bucket"
echo "  → Enable versioning and encryption (AES256)"
echo "  → Block public access"
echo "  → Upload sample file"
echo "  → Output: Bucket name and contents"
echo ""
echo -e "${GREEN}cleanup_resources.sh${NC}"
echo "  → Delete all AutomationLab tagged resources"
echo "  → Supports --dry-run mode"
echo "  → Requires confirmation"
echo "  → Cleans: EC2, Security Groups, S3, Key Pairs"
echo ""

echo -e "${CYAN}📚 Documentation Files:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}README.md${NC}"
echo "  → Complete project documentation"
echo "  → Setup instructions and usage guide"
echo "  → Challenges and solutions"
echo ""
echo -e "${GREEN}QUICK_REFERENCE.md${NC}"
echo "  → Command cheat sheet"
echo "  → Common operations and queries"
echo ""
echo -e "${GREEN}TROUBLESHOOTING.md${NC}"
echo "  → Common issues and solutions"
echo "  → Debugging tips"
echo ""
echo -e "${GREEN}SCREENSHOTS_GUIDE.md${NC}"
echo "  → Required screenshots for submission"
echo "  → Screenshot organization guide"
echo ""
echo -e "${GREEN}PROJECT_CHECKLIST.md${NC}"
echo "  → Complete project checklist"
echo "  → Submission requirements"
echo ""

echo -e "${CYAN}🎯 Learning Objectives:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "✓ Use AWS CLI to manage cloud resources"
echo -e "✓ Write Bash scripts for infrastructure automation"
echo -e "✓ Implement error handling and validation"
echo -e "✓ Apply security best practices"
echo -e "✓ Use resource tagging for management"
echo -e "✓ Automate resource cleanup"
echo ""

echo -e "${CYAN}🔧 Prerequisites:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "• AWS CLI v2 installed"
echo -e "• AWS credentials configured"
echo -e "• IAM permissions: ec2:*, s3:*, sts:GetCallerIdentity"
echo -e "• Default region set"
echo ""

echo -e "${CYAN}📦 Expected Deliverables:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "✓ create_ec2.sh"
echo -e "✓ create_security_group.sh"
echo -e "✓ create_s3_bucket.sh"
echo -e "✓ cleanup_resources.sh"
echo -e "✓ README.md with complete documentation"
echo -e "✓ Screenshots showing successful execution"
echo -e "✓ GitHub repository"
echo ""

echo -e "${CYAN}🔐 Security Features:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "✓ No hardcoded credentials"
echo -e "✓ .pem files with correct permissions (400)"
echo -e "✓ S3 encryption enabled (AES256)"
echo -e "✓ S3 public access blocked"
echo -e "✓ Resource tagging for identification"
echo -e "✓ .gitignore prevents sensitive file commits"
echo ""

echo -e "${CYAN}💡 Tips:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "• Run setup.sh first to verify environment"
echo -e "• Create security group before EC2 instance"
echo -e "• Use --dry-run for cleanup preview"
echo -e "• Check AWS Console to verify resources"
echo -e "• Save generated .txt files for reference"
echo -e "• Always cleanup resources to avoid charges"
echo -e "• Take screenshots as you go"
echo ""

echo -e "${CYAN}📞 Getting Help:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "• Check ${GREEN}TROUBLESHOOTING.md${NC} for common issues"
echo -e "• Review ${GREEN}README.md${NC} for detailed documentation"
echo -e "• See ${GREEN}QUICK_REFERENCE.md${NC} for command examples"
echo -e "• AWS Documentation: https://docs.aws.amazon.com/"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Ready to get started? Run: ${GREEN}./setup.sh${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
