#!/bin/bash

################################################################################
# Script: create_s3_bucket.sh
# Purpose: Automate S3 bucket creation with versioning and sample upload
# Author: DevOps Automation Lab
# Date: December 23, 2025
################################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
BUCKET_PREFIX="automation-lab-bucket"
TIMESTAMP=$(date +%s)
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
PROJECT_TAG="aws-resource-creation"

# Output directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$(dirname "${SCRIPT_DIR}")/outputs"
LOG_DIR="${OUTPUT_DIR}/logs"
INFO_DIR="${OUTPUT_DIR}/info"
SAMPLE_DIR="${OUTPUT_DIR}/samples"

mkdir -p "${LOG_DIR}" "${INFO_DIR}" "${SAMPLE_DIR}"

LOG_FILE="${LOG_DIR}/s3_creation_$(date +%Y%m%d_%H%M%S).log"
INFO_FILE="${INFO_DIR}/s3_bucket_info.txt"
SAMPLE_FILE="${SAMPLE_DIR}/welcome.txt"

################################################################################
# Logging Functions
################################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

log_info() {
    log "INFO" "$@"
    print_info "$@"
}

log_success() {
    log "SUCCESS" "$@"
    print_success "$@"
}

log_error() {
    log "ERROR" "$@"
    print_error "$@"
}

################################################################################
# Output Functions
################################################################################

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

################################################################################
# Error Handling
################################################################################

cleanup_on_error() {
    local exit_code=$?
    log_error "Script failed with exit code: ${exit_code}"
    
    if [[ -n "${BUCKET_NAME:-}" ]]; then
        log_error "Cleaning up bucket: ${BUCKET_NAME}"
        aws s3 rm "s3://${BUCKET_NAME}" --recursive --region "${REGION}" 2>/dev/null || true
        aws s3api delete-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" 2>/dev/null || true
    fi
    
    [[ -f "${SAMPLE_FILE}" ]] && rm -f "${SAMPLE_FILE}"
    
    log_info "Check log file: ${LOG_FILE}"
    exit "${exit_code}"
}

trap cleanup_on_error ERR INT TERM

################################################################################
# Validation Functions
################################################################################

check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    log_success "AWS CLI found"
}

check_aws_credentials() {
    log_info "Verifying AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured properly."
        echo "Please run: aws configure"
        exit 1
    fi
    log_success "AWS credentials verified"
}

get_account_id() {
    log "INFO" "Getting AWS account ID..."
    local account_id=$(aws sts get-caller-identity --query 'Account' --output text 2>> "${LOG_FILE}")
    log "SUCCESS" "Account ID: ${account_id}"
    echo "${account_id}"
}

################################################################################
# Core Functions
################################################################################

generate_bucket_name() {
    local account_id="$1"
    local bucket_name="${BUCKET_PREFIX}-${account_id}-${TIMESTAMP}"
    log "INFO" "Generated bucket name: ${bucket_name}"
    echo "${bucket_name}"
}

create_bucket() {
    local bucket_name="$1"
    
    log "INFO" "Creating S3 bucket: ${bucket_name}..."
    
    # For us-east-1, we don't specify LocationConstraint
    if [[ "${REGION}" == "us-east-1" ]]; then
        if aws s3api create-bucket \
            --bucket "${bucket_name}" \
            --region "${REGION}" &>> "${LOG_FILE}"; then
            log "SUCCESS" "S3 bucket created: ${bucket_name}"
            return 0
        fi
    else
        if aws s3api create-bucket \
            --bucket "${bucket_name}" \
            --region "${REGION}" \
            --create-bucket-configuration LocationConstraint="${REGION}" &>> "${LOG_FILE}"; then
            log "SUCCESS" "S3 bucket created: ${bucket_name}"
            return 0
        fi
    fi
    
    log_error "Failed to create S3 bucket"
    return 1
}

add_bucket_tags() {
    local bucket_name="$1"
    
    log_info "Adding tags to bucket..."
    
    if aws s3api put-bucket-tagging \
        --bucket "${bucket_name}" \
        --tagging "TagSet=[{Key=Name,Value=${bucket_name}},{Key=Project,Value=${PROJECT_TAG}},{Key=ManagedBy,Value=AutomationScript},{Key=CreatedBy,Value=create_s3_bucket.sh}]" \
        --region "${REGION}" &>> "${LOG_FILE}"; then
        log_success "Tags added to bucket"
        return 0
    else
        log_error "Failed to add tags"
        return 1
    fi
}

enable_versioning() {
    local bucket_name="$1"
    
    log_info "Enabling versioning on bucket..."
    
    if aws s3api put-bucket-versioning \
        --bucket "${bucket_name}" \
        --versioning-configuration Status=Enabled \
        --region "${REGION}" &>> "${LOG_FILE}"; then
        log_success "Versioning enabled"
        return 0
    else
        log_error "Failed to enable versioning"
        return 1
    fi
}

enable_encryption() {
    local bucket_name="$1"
    
    log_info "Enabling server-side encryption..."
    
    if aws s3api put-bucket-encryption \
        --bucket "${bucket_name}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }]
        }' \
        --region "${REGION}" &>> "${LOG_FILE}"; then
        log_success "Server-side encryption enabled"
        return 0
    else
        log_error "Failed to enable encryption (continuing...)"
        return 1
    fi
}

block_public_access() {
    local bucket_name="$1"
    
    log_info "Configuring public access block..."
    
    if aws s3api put-public-access-block \
        --bucket "${bucket_name}" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        --region "${REGION}" &>> "${LOG_FILE}"; then
        log_success "Public access blocked (security best practice)"
        return 0
    else
        log_error "Failed to block public access (continuing...)"
        return 1
    fi
}

create_sample_file() {
    local bucket_name="$1"
    
    log_info "Creating sample file: ${SAMPLE_FILE}..."
    
    cat > "${SAMPLE_FILE}" << EOF
Welcome to the AWS Automation Lab!
===================================

This file was automatically uploaded by the create_s3_bucket.sh script.

Bucket Information:
- Bucket Name: ${bucket_name}
- Region: ${REGION}
- Created: $(date)
- Project: ${PROJECT_TAG}

This bucket has the following features enabled:
✓ Versioning
✓ Server-side encryption (AES256)
✓ Public access blocked

This is a demonstration of AWS S3 automation using Bash and AWS CLI.

Happy Learning!
EOF
    
    log_success "Sample file created"
}

upload_file() {
    local bucket_name="$1"
    local file="$2"
    local key="${3:-${file}}"
    
    log_info "Uploading ${file} to S3 bucket..."
    
    if aws s3 cp "${file}" "s3://${bucket_name}/${key}" \
        --region "${REGION}" &>> "${LOG_FILE}"; then
        log_success "File uploaded successfully: ${key}"
        return 0
    else
        log_error "Failed to upload file: ${key}"
        return 1
    fi
}

upload_file_with_metadata() {
    local bucket_name="$1"
    local file="$2"
    
    log_info "Uploading file with metadata..."
    
    if aws s3 cp "${file}" "s3://${bucket_name}/metadata-${file}" \
        --metadata "project=${PROJECT_TAG},uploadedby=automation-script,timestamp=${TIMESTAMP}" \
        --region "${REGION}" &>> "${LOG_FILE}"; then
        log_success "File with metadata uploaded"
        return 0
    else
        return 1
    fi
}

list_bucket_contents() {
    local bucket_name="$1"
    
    log_info "Listing bucket contents..."
    
    aws s3 ls "s3://${bucket_name}/" --region "${REGION}" 2>> "${LOG_FILE}"
}

get_versioning_status() {
    local bucket_name="$1"
    
    aws s3api get-bucket-versioning \
        --bucket "${bucket_name}" \
        --query 'Status' \
        --output text \
        --region "${REGION}" 2>> "${LOG_FILE}"
}

save_bucket_info() {
    local bucket_name="$1"
    local versioning_status="$2"
    local bucket_contents="$3"
    
    cat > "${INFO_FILE}" << EOF
S3 Bucket Information
=====================
Bucket Name: ${bucket_name}
Region: ${REGION}
Versioning Status: ${versioning_status}
Encryption: Enabled (AES256)
Public Access: Blocked
Created: $(date)
Log File: ${LOG_FILE}

Bucket Contents:
----------------
${bucket_contents}

AWS CLI Commands:
-----------------
List bucket:
  aws s3 ls s3://${bucket_name}/

Upload file:
  aws s3 cp <local-file> s3://${bucket_name}/

Download file:
  aws s3 cp s3://${bucket_name}/${SAMPLE_FILE} ./

View in console:
  https://s3.console.aws.amazon.com/s3/buckets/${bucket_name}?region=${REGION}
EOF
    
    log_success "Bucket information saved to ${INFO_FILE}"
}

print_summary() {
    local bucket_name="$1"
    local versioning_status="$2"
    local bucket_contents="$3"
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}S3 Bucket Created Successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "Bucket Name:        ${GREEN}${bucket_name}${NC}"
    echo -e "Region:             ${GREEN}${REGION}${NC}"
    echo -e "Versioning Status:  ${GREEN}${versioning_status}${NC}"
    echo -e "Encryption:         ${GREEN}Enabled (AES256)${NC}"
    echo -e "Public Access:      ${GREEN}Blocked${NC}"
    echo -e "Log File:           ${GREEN}${LOG_FILE}${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Bucket Contents:${NC}"
    echo "${bucket_contents}" | while read -r line; do
        if [[ -n "${line}" ]]; then
            echo -e "  ${GREEN}✓${NC} ${line}"
        fi
    done
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo -e "List bucket:     ${GREEN}aws s3 ls s3://${bucket_name}/${NC}"
    echo -e "Download file:   ${GREEN}aws s3 cp s3://${bucket_name}/${SAMPLE_FILE} ./${NC}"
    echo -e "Delete bucket:   ${GREEN}aws s3 rb s3://${bucket_name} --force${NC}"
    echo ""
    echo -e "${YELLOW}View in AWS Console:${NC}"
    echo -e "https://s3.console.aws.amazon.com/s3/buckets/${bucket_name}?region=${REGION}"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}S3 Bucket Creation Script${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    log_info "Starting S3 bucket creation process"
    log_info "Log file: ${LOG_FILE}"
    
    # Validations
    check_aws_cli
    check_aws_credentials
    
    # Generate bucket name
    print_info "Getting AWS account ID..."
    local ACCOUNT_ID=$(get_account_id)
    print_success "Account ID: ${ACCOUNT_ID}"
    
    print_info "Generating bucket name..."
    BUCKET_NAME=$(generate_bucket_name "${ACCOUNT_ID}")
    print_success "Bucket name: ${BUCKET_NAME}"
    
    # Create and configure bucket
    print_info "Creating S3 bucket: ${BUCKET_NAME}..."
    create_bucket "${BUCKET_NAME}"
    print_success "S3 bucket created: ${BUCKET_NAME}"
    add_bucket_tags "${BUCKET_NAME}"
    enable_versioning "${BUCKET_NAME}"
    enable_encryption "${BUCKET_NAME}"
    block_public_access "${BUCKET_NAME}"
    
    # Upload files
    create_sample_file "${BUCKET_NAME}"
    upload_file "${BUCKET_NAME}" "${SAMPLE_FILE}"
    upload_file_with_metadata "${BUCKET_NAME}" "${SAMPLE_FILE}"
    
    # Get bucket information
    local BUCKET_CONTENTS=$(list_bucket_contents "${BUCKET_NAME}")
    local VERSIONING_STATUS=$(get_versioning_status "${BUCKET_NAME}")
    
    # Save and display results
    save_bucket_info "${BUCKET_NAME}" "${VERSIONING_STATUS}" "${BUCKET_CONTENTS}"
    print_summary "${BUCKET_NAME}" "${VERSIONING_STATUS}" "${BUCKET_CONTENTS}"
    
    log_success "S3 bucket creation completed successfully"
}

# Run main function
main "$@"
print_info "Verifying AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials are not configured properly."
    echo "Please run: aws configure"
    exit 1
fi
print_success "AWS credentials verified"

# Create S3 bucket
print_info "Creating S3 bucket: $BUCKET_NAME..."

# For us-east-1, we don't specify LocationConstraint
if [ "$REGION" == "us-east-1" ]; then
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" > /dev/null
else
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION" > /dev/null
fi

if [ $? -eq 0 ]; then
    print_success "S3 bucket created: $BUCKET_NAME"
else
    print_error "Failed to create S3 bucket"
    exit 1
fi

# Add tags to bucket
print_info "Adding tags to bucket..."
aws s3api put-bucket-tagging \
    --bucket "$BUCKET_NAME" \
    --tagging "TagSet=[{Key=Name,Value=$BUCKET_NAME},{Key=Project,Value=$PROJECT_TAG},{Key=ManagedBy,Value=AutomationScript}]" \
    --region "$REGION"

if [ $? -eq 0 ]; then
    print_success "Tags added to bucket"
else
    print_error "Failed to add tags"
fi

# Enable versioning
print_info "Enabling versioning on bucket..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$REGION"

if [ $? -eq 0 ]; then
    print_success "Versioning enabled"
else
    print_error "Failed to enable versioning"
fi

# Enable server-side encryption (AES256)
print_info "Enabling server-side encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }' \
    --region "$REGION" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    print_success "Server-side encryption enabled"
else
    print_error "Failed to enable encryption (continuing...)"
fi

# Block public access (security best practice)
print_info "Configuring public access block..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region "$REGION" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    print_success "Public access blocked (security best practice)"
else
    print_error "Failed to block public access (continuing...)"
fi

# Create a sample welcome.txt file
print_info "Creating sample file: $SAMPLE_FILE..."
cat > "$SAMPLE_FILE" << EOF
Welcome to the AWS Automation Lab!
===================================

This file was automatically uploaded by the create_s3_bucket.sh script.

Bucket Information:
- Bucket Name: $BUCKET_NAME
- Region: $REGION
- Created: $(date)
- Project: $PROJECT_TAG

This bucket has the following features enabled:
✓ Versioning
✓ Server-side encryption (AES256)
✓ Public access blocked

This is a demonstration of AWS S3 automation using Bash and AWS CLI.

Happy Learning!
EOF

print_success "Sample file created"

# Upload sample file to S3
print_info "Uploading $SAMPLE_FILE to S3 bucket..."
aws s3 cp "$SAMPLE_FILE" "s3://${BUCKET_NAME}/${SAMPLE_FILE}" \
    --region "$REGION" > /dev/null

if [ $? -eq 0 ]; then
    print_success "File uploaded successfully"
else
    print_error "Failed to upload file"
fi

# Upload with metadata
print_info "Uploading file with metadata..."
aws s3 cp "$SAMPLE_FILE" "s3://${BUCKET_NAME}/metadata-${SAMPLE_FILE}" \
    --metadata "project=$PROJECT_TAG,uploadedby=automation-script,timestamp=$TIMESTAMP" \
    --region "$REGION" > /dev/null

if [ $? -eq 0 ]; then
    print_success "File with metadata uploaded"
fi

# List bucket contents
print_info "Listing bucket contents..."
BUCKET_CONTENTS=$(aws s3 ls "s3://${BUCKET_NAME}/" --region "$REGION")

# Get bucket details
VERSIONING_STATUS=$(aws s3api get-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --query 'Status' \
    --output text \
    --region "$REGION")

# Display summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}S3 Bucket Created Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Bucket Name:        ${GREEN}$BUCKET_NAME${NC}"
echo -e "Region:             ${GREEN}$REGION${NC}"
echo -e "Versioning Status:  ${GREEN}$VERSIONING_STATUS${NC}"
echo -e "Encryption:         ${GREEN}Enabled (AES256)${NC}"
echo -e "Public Access:      ${GREEN}Blocked${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Bucket Contents:${NC}"
echo "$BUCKET_CONTENTS" | while read -r line; do
    if [ ! -z "$line" ]; then
        echo -e "  ${GREEN}✓${NC} $line"
    fi
done
echo ""
echo -e "${GREEN}========================================${NC}"
echo ""

# Save bucket information to file
cat > s3_bucket_info.txt << EOF
S3 Bucket Information
=====================
Bucket Name: $BUCKET_NAME
Region: $REGION
Versioning Status: $VERSIONING_STATUS
Encryption: Enabled (AES256)
Public Access: Blocked
Created: $(date)

Bucket Contents:
----------------
$BUCKET_CONTENTS

AWS CLI Commands:
-----------------
List bucket:
  aws s3 ls s3://$BUCKET_NAME/

Upload file:
  aws s3 cp <local-file> s3://$BUCKET_NAME/

Download file:
  aws s3 cp s3://$BUCKET_NAME/$SAMPLE_FILE ./

View in console:
  https://s3.console.aws.amazon.com/s3/buckets/$BUCKET_NAME?region=$REGION
EOF

print_success "Bucket information saved to s3_bucket_info.txt"

echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "List bucket:     ${GREEN}aws s3 ls s3://$BUCKET_NAME/${NC}"
echo -e "Download file:   ${GREEN}aws s3 cp s3://$BUCKET_NAME/$SAMPLE_FILE ./${NC}"
echo -e "Delete bucket:   ${GREEN}aws s3 rb s3://$BUCKET_NAME --force${NC}"
echo ""
echo -e "${YELLOW}View in AWS Console:${NC}"
echo -e "https://s3.console.aws.amazon.com/s3/buckets/$BUCKET_NAME?region=$REGION"
echo ""
