# AWS Resource Creation Automation Project

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

## 📋 Project Overview


**Project Goal:** Develop Bash scripts that automate the creation and configuration of essential AWS resources programmatically, applying best practices for parameterization, error handling, and resource cleanup.

## 🎯 Learning Objectives

- ✅ Use the AWS CLI to create and manage cloud resources programmatically
- ✅ Write and execute Bash scripts to automate routine infrastructure setup tasks
- ✅ Apply best practices for parameterization, error handling, and resource cleanup
- ✅ Demonstrate security principles through proper IAM credentials and permissions
- ✅ Implement tagging strategies for resource management

## 🗂️ Project Structure

```
aws-resource-creation/
├── scripts/
│   ├── create_ec2.sh              # EC2 instance creation automation
│   ├── create_security_group.sh   # Security group creation automation
│   ├── create_s3_bucket.sh         # S3 bucket creation automation
│   ├── cleanup_resources.sh        # Resource cleanup automation
│   ├── setup.sh                    # Setup verification script
│   ├── project_info.sh             # Project information display
│   └── README.md                   # This file
├── outputs/                        # Generated files (git-ignored)
│   ├── logs/                       # Timestamped execution logs
│   ├── keys/                       # SSH private keys (.pem files)
│   ├── info/                       # Resource information files
│   ├── samples/                    # Sample files for S3 uploads
│   └── README.md                   # Outputs documentation
├── .gitignore                      # Git exclusions (keys, logs, etc.)
└── README.md                       # Main project documentation
```

## 📁 Output Files Organization

All generated files are automatically organized in the `outputs/` directory:

- **logs/**: Timestamped log files (`*_creation_YYYYMMDD_HHMMSS.log`)
- **keys/**: SSH private keys (`automation-lab-key-*.pem`) - **Never committed to git!**
- **info/**: Resource details (`ec2_instance_info.txt`, `security_group_info.txt`, etc.)
- **samples/**: Sample files for testing (`welcome.txt`)

See `outputs/README.md` for detailed information about output file management.

## 🚀 Scripts Overview

### 1. create_ec2.sh
**Purpose:** Automates the creation of EC2 instances with key pairs and proper tagging.

**Features:**
- ✅ Creates EC2 key pair automatically
- ✅ Fetches latest Amazon Linux 2 AMI
- ✅ Launches t2.micro instance (free-tier eligible)
- ✅ Tags instance with 'Project=AutomationLab'
- ✅ Outputs instance ID, public IP, and SSH connection command
- ✅ Saves key pair to local .pem file with correct permissions
- ✅ Generates detailed instance information file

**Usage:**
```bash
chmod +x create_ec2.sh
./create_ec2.sh
```

**Output Example:**
```
Instance ID:     i-0123456789abcdef0
Public IP:       54.123.45.67
Key File:        automation-lab-key-1234567890.pem
SSH Command:     ssh -i automation-lab-key-1234567890.pem ec2-user@54.123.45.67
```

---

### 2. create_security_group.sh
**Purpose:** Automates the creation of security groups with predefined ingress rules.

**Features:**
- ✅ Creates security group in default VPC
- ✅ Opens port 22 (SSH) for remote access
- ✅ Opens port 80 (HTTP) for web traffic
- ✅ Opens port 443 (HTTPS) for secure web traffic
- ✅ Tags security group with 'Project=AutomationLab'
- ✅ Displays security group ID and all configured rules
- ✅ Generates security group information file

**Usage:**
```bash
chmod +x create_security_group.sh
./create_security_group.sh
```

**Output Example:**
```
Security Group ID:   sg-0123456789abcdef0
Security Group Name: devops-sg-1234567890

Inbound Rules:
  ✓ Protocol: tcp | Port: 22  | Source: 0.0.0.0/0 | Service: SSH
  ✓ Protocol: tcp | Port: 80  | Source: 0.0.0.0/0 | Service: HTTP
  ✓ Protocol: tcp | Port: 443 | Source: 0.0.0.0/0 | Service: HTTPS
```

---

### 3. create_s3_bucket.sh
**Purpose:** Automates S3 bucket creation with versioning, encryption, and sample file upload.

**Features:**
- ✅ Creates uniquely named S3 bucket (account-specific naming)
- ✅ Enables bucket versioning
- ✅ Enables server-side encryption (AES256)
- ✅ Blocks public access (security best practice)
- ✅ Tags bucket with 'Project=AutomationLab'
- ✅ Uploads sample welcome.txt file
- ✅ Adds custom metadata to uploaded files
- ✅ Generates bucket information file with useful commands

**Usage:**
```bash
chmod +x create_s3_bucket.sh
./create_s3_bucket.sh
```

**Output Example:**
```
Bucket Name:        automation-lab-bucket-123456789012-1234567890
Region:             us-east-1
Versioning Status:  Enabled
Encryption:         Enabled (AES256)
Public Access:      Blocked

Bucket Contents:
  ✓ 2025-12-23 10:30:45        156 welcome.txt
  ✓ 2025-12-23 10:30:46        156 metadata-welcome.txt
```

---

### 4. cleanup_resources.sh
**Purpose:** Safely terminates and deletes all resources created by the automation scripts.

**Features:**
- ✅ Identifies resources by Project tag
- ✅ Terminates EC2 instances
- ✅ Deletes key pairs (AWS and local .pem files)
- ✅ Deletes security groups
- ✅ Empties and deletes S3 buckets (including versioned objects)
- ✅ Cleans up local information files
- ✅ Supports dry-run mode for safe testing
- ✅ Requires confirmation before deletion

**Usage:**
```bash
chmod +x cleanup_resources.sh

# Dry run (preview what would be deleted)
./cleanup_resources.sh --dry-run

# Actual cleanup (requires confirmation)
./cleanup_resources.sh

# Specify region
./cleanup_resources.sh --region us-west-2
```

**Safety Features:**
- Requires explicit "yes" confirmation
- Provides dry-run mode to preview deletions
- Uses tag-based filtering to avoid accidental deletions
- Handles versioned S3 objects properly

---

## 🛠️ Prerequisites

### 1. AWS Account
- Active AWS account with appropriate permissions
- IAM user with programmatic access

### 2. Required IAM Permissions
Your IAM user needs the following permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "s3:*",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3. Software Requirements
- **Operating System:** Linux, macOS, or WSL2 on Windows
- **Bash:** Version 4.0 or higher
- **AWS CLI:** Version 2.x (recommended)

---

## 📦 Installation & Setup

### Step 1: Install AWS CLI

**On Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**On macOS:**
```bash
brew install awscli
```

**Verify installation:**
```bash
aws --version
```

### Step 2: Configure AWS CLI

```bash
aws configure
```

Enter your credentials:
```
AWS Access Key ID [None]: YOUR_ACCESS_KEY
AWS Secret Access Key [None]: YOUR_SECRET_KEY
Default region name [None]: us-east-1
Default output format [None]: json
```

### Step 3: Verify AWS Configuration

```bash
# Check your identity
aws sts get-caller-identity

# List configuration
aws configure list
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### Step 4: Clone or Download Scripts

```bash
git clone <repository-url>
cd aws-resource-creation
```

### Step 5: Make Scripts Executable

```bash
chmod +x create_ec2.sh
chmod +x create_security_group.sh
chmod +x create_s3_bucket.sh
chmod +x cleanup_resources.sh
```

---

## 🎮 Usage Guide

### Quick Start - Complete Workflow

```bash
# 1. Create security group first (for use with EC2)
./create_security_group.sh

# 2. Create EC2 instance
./create_ec2.sh

# 3. Create S3 bucket
./create_s3_bucket.sh

# 4. Review created resources in AWS Console

# 5. When done, cleanup everything
./cleanup_resources.sh
```

### Individual Script Usage

**Create EC2 Instance:**
```bash
./create_ec2.sh
# Wait for completion, note the SSH command
ssh -i automation-lab-key-*.pem ec2-user@<PUBLIC_IP>
```

**Create Security Group:**
```bash
./create_security_group.sh
# Note the security group ID for use with EC2 instances
```

**Create S3 Bucket:**
```bash
./create_s3_bucket.sh
# Bucket is created with versioning and encryption enabled
aws s3 ls s3://automation-lab-bucket-*
```

**Cleanup All Resources:**
```bash
# Dry run first (recommended)
./cleanup_resources.sh --dry-run

# Actual cleanup
./cleanup_resources.sh
# Type 'yes' when prompted
```

---

## 🔐 Security Best Practices

### 1. Key Management
- ✅ Scripts automatically set correct permissions (400) on .pem files
- ✅ Keep .pem files secure and never commit to version control
- ✅ Delete key pairs when no longer needed

### 2. Security Groups
- ⚠️ Scripts use 0.0.0.0/0 for demonstration purposes
- 🔒 **Production:** Restrict to specific IP ranges
- 🔒 **Production:** Use VPN or bastion hosts for SSH access

### 3. S3 Buckets
- ✅ Scripts enable encryption by default (AES256)
- ✅ Scripts block all public access
- ✅ Scripts enable versioning for data protection

### 4. IAM Credentials
- 🔒 Never hardcode credentials in scripts
- 🔒 Use AWS CLI configuration or IAM roles
- 🔒 Rotate access keys regularly
- 🔒 Use least-privilege principle

### 5. Tagging Strategy
- ✅ All resources tagged with 'Project=AutomationLab'
- ✅ Enables easy identification and cleanup
- ✅ Supports cost tracking and resource management

---

## 📊 Generated Files

Each script generates information files for reference:

| File | Description |
|------|-------------|
| `ec2_instance_info.txt` | EC2 instance details, SSH command |
| `security_group_info.txt` | Security group ID, rules |
| `s3_bucket_info.txt` | Bucket name, region, useful commands |
| `welcome.txt` | Sample file uploaded to S3 |
| `*.pem` | EC2 key pair private key files |

---

## 🐛 Troubleshooting

### Issue: "AWS CLI not found"
**Solution:**
```bash
# Check if AWS CLI is installed
which aws

# If not, install it (see Installation section)
```

### Issue: "Credentials not configured"
**Solution:**
```bash
aws configure
# Enter your AWS credentials
```

### Issue: "Permission denied" when running scripts
**Solution:**
```bash
chmod +x *.sh
```

### Issue: "Default VPC not found"
**Solution:**
```bash
# Create a default VPC
aws ec2 create-default-vpc
```

### Issue: "Bucket name already exists"
**Solution:**
- S3 bucket names must be globally unique
- Scripts use timestamp to ensure uniqueness
- If issue persists, check for existing buckets:
```bash
aws s3 ls
```

### Issue: "Security group cannot be deleted"
**Solution:**
- Security groups cannot be deleted if attached to running instances
- Terminate instances first:
```bash
./cleanup_resources.sh
```

### Issue: "Region not supported"
**Solution:**
```bash
# Check available regions
aws ec2 describe-regions --output table

# Set different region
export AWS_DEFAULT_REGION=us-west-2
```

---

## 💡 Challenges Faced & Solutions

### Challenge 1: AMI Selection
**Problem:** Different regions have different AMIs, hardcoding AMI IDs fails in other regions.

**Solution:** Scripts dynamically fetch the latest Amazon Linux 2 AMI using `describe-images` with filters.

```bash
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
              "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)
```

### Challenge 2: S3 Bucket Naming
**Problem:** S3 bucket names must be globally unique across all AWS accounts.

**Solution:** Implemented naming strategy using account ID and timestamp:
```bash
BUCKET_NAME="${BUCKET_PREFIX}-${ACCOUNT_ID}-${TIMESTAMP}"
```

### Challenge 3: Region-Specific S3 Creation
**Problem:** `us-east-1` requires different bucket creation syntax than other regions.

**Solution:** Conditional logic based on region:
```bash
if [ "$REGION" == "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
fi
```

### Challenge 4: Versioned S3 Bucket Cleanup
**Problem:** Simply deleting a bucket fails if it contains versioned objects.

**Solution:** Implemented comprehensive cleanup that removes all versions and delete markers:
```bash
# Delete all object versions
aws s3api delete-objects --bucket "$BUCKET" \
    --delete "$(aws s3api list-object-versions --bucket "$BUCKET" \
        --query '{Objects: Versions[].{Key: Key, VersionId: VersionId}}')"

# Delete all delete markers
aws s3api delete-objects --bucket "$BUCKET" \
    --delete "$(aws s3api list-object-versions --bucket "$BUCKET" \
        --query '{Objects: DeleteMarkers[].{Key: Key, VersionId: VersionId}}')"
```

### Challenge 5: Error Handling & User Feedback
**Problem:** Users need clear feedback on script progress and errors.

**Solution:** Implemented colored output, progress indicators, and comprehensive error messages:
```bash
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}→ $1${NC}"; }
```

---

## 🎯 Advanced Features

### 1. Environment Variables
Scripts respect standard AWS environment variables:
```bash
export AWS_DEFAULT_REGION=us-west-2
export AWS_PROFILE=dev-profile
./create_ec2.sh
```

### 2. Dry Run Mode (cleanup script)
```bash
./cleanup_resources.sh --dry-run
```

### 3. Custom Tagging
Modify the `PROJECT_TAG` variable in scripts for custom tagging:
```bash
PROJECT_TAG="MyProject"
```

### 4. Metadata and Object Tagging
S3 script adds custom metadata to uploaded objects:
```bash
aws s3 cp file.txt s3://bucket/ \
    --metadata "project=AutomationLab,timestamp=$(date +%s)"
```

---

## 📸 Screenshots

> **Note:** Take screenshots showing:
> 1. AWS CLI configuration verification (`aws sts get-caller-identity`)
> 2. Successful execution of each script
> 3. AWS Console showing created resources
> 4. Successful cleanup execution

### Recommended Screenshots:
1. **Terminal output** of `create_ec2.sh` showing instance creation
2. **AWS EC2 Console** showing the running instance with tags
3. **Terminal output** of `create_security_group.sh` showing rules
4. **AWS EC2 Console** showing the security group details
5. **Terminal output** of `create_s3_bucket.sh` showing bucket creation
6. **AWS S3 Console** showing the bucket with uploaded files
7. **Terminal output** of `cleanup_resources.sh` showing resource deletion

---

## 🔄 CI/CD Integration (Optional Enhancement)

These scripts can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
name: AWS Infrastructure Deployment
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      - name: Deploy Infrastructure
        run: |
          chmod +x *.sh
          ./create_security_group.sh
          ./create_ec2.sh
          ./create_s3_bucket.sh
```

---

## 📚 Additional Resources

### AWS CLI Documentation
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [EC2 CLI Commands](https://docs.aws.amazon.com/cli/latest/reference/ec2/)
- [S3 CLI Commands](https://docs.aws.amazon.com/cli/latest/reference/s3/)

### AWS Best Practices
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [AWS Tagging Strategies](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html)
- [EC2 Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-best-practices.html)

### Bash Scripting
- [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/)
- [Bash Error Handling](https://www.gnu.org/software/bash/manual/bash.html#The-Set-Builtin)

---

## 🤝 Contributing

Contributions are welcome! Areas for improvement:
- Additional AWS services (RDS, Lambda, etc.)
- Enhanced error handling
- Cost estimation features
- Multi-region support
- Infrastructure state management

---

## 📝 License

This project is created for educational purposes as part of the DevOps Automation Lab.

---

## ✅ Submission Checklist

- [x] All required scripts created and tested
- [x] Scripts include comprehensive error handling
- [x] Resources properly tagged for identification
- [x] Cleanup script safely removes all resources
- [x] README.md with complete documentation
- [ ] Screenshots of successful execution
- [ ] GitHub repository created
- [ ] All files committed and pushed

---

## 👤 Author

**DevOps Automation Lab**  
Date: December 23, 2025

---

## 📞 Support

For issues or questions:
1. Check the Troubleshooting section
2. Review AWS CloudWatch logs
3. Verify IAM permissions
4. Check AWS service quotas

---

**Happy Automating! 🚀**
