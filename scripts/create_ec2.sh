#!/bin/bash

################################################################################
# Script: create_ec2.sh
# Purpose: Automate EC2 instance creation with key pair and tagging
# Author: Abraham Ayamigah
# Date: December 23, 2025
################################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
KEY_NAME="automation-lab-key-$(date +%s)"
INSTANCE_TYPE="t3.micro"
PROJECT_TAG="aws-resource-creation"
REGION="${AWS_DEFAULT_REGION:-eu-west-1}"

# Output directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$(dirname "${SCRIPT_DIR}")/outputs"
LOG_DIR="${OUTPUT_DIR}/logs"
KEY_DIR="${OUTPUT_DIR}/keys"
INFO_DIR="${OUTPUT_DIR}/info"

mkdir -p "${LOG_DIR}" "${KEY_DIR}" "${INFO_DIR}"

LOG_FILE="${LOG_DIR}/ec2_creation_$(date +%Y%m%d_%H%M%S).log"
INFO_FILE="${INFO_DIR}/ec2_instance_info.txt"

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

log_warning() {
    log "WARNING" "$@"
    echo -e "${YELLOW}⚠ $*${NC}"
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
# Cleanup and Error Handling
################################################################################

cleanup_on_error() {
    local exit_code=$?
    log_error "Script failed with exit code: ${exit_code}"
    
    if [[ -n "${KEY_NAME:-}" ]] && [[ -f "${KEY_NAME}.pem" ]]; then
        log_warning "Cleaning up created key pair due to error"
        aws ec2 delete-key-pair --key-name "${KEY_NAME}" --region "${REGION}" 2>/dev/null || true
        rm -f "${KEY_NAME}.pem"
    fi
    
    if [[ -n "${INSTANCE_ID:-}" ]]; then
        log_warning "Terminating partially created instance: ${INSTANCE_ID}"
        aws ec2 terminate-instances --instance-ids "${INSTANCE_ID}" --region "${REGION}" 2>/dev/null || true
    fi
    
    log_info "Cleanup completed. Check log file: ${LOG_FILE}"
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
    log_success "AWS CLI found: $(aws --version 2>&1 | head -n1)"
}

check_aws_credentials() {
    log_info "Verifying AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured properly."
        echo "Please run: aws configure"
        exit 1
    fi
    
    local caller_identity=$(aws sts get-caller-identity --output json)
    local account_id=$(echo "${caller_identity}" | grep -o '"Account": "[^"]*' | cut -d'"' -f4)
    log_success "AWS credentials verified for account: ${account_id}"
}

validate_region() {
    log_info "Validating AWS region: ${REGION}"
    if ! aws ec2 describe-regions --region-names "${REGION}" &> /dev/null; then
        log_error "Invalid or unsupported region: ${REGION}"
        exit 1
    fi
    log_success "Region validated: ${REGION}"
}

################################################################################
# Core Functions
################################################################################

get_latest_ami() {
    log "INFO" "Fetching latest Amazon Linux 2 AMI..."
    
    local ami_id=$(aws ec2 describe-images \
        --owners amazon \
        --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
                  "Name=state,Values=available" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --output text \
        --region "${REGION}" 2>> "${LOG_FILE}")
    
    if [[ -z "${ami_id}" ]] || [[ "${ami_id}" == "None" ]]; then
        log_error "Failed to fetch Amazon Linux 2 AMI"
        exit 1
    fi
    
    log "SUCCESS" "AMI ID: ${ami_id}"
    echo "${ami_id}"
}

create_key_pair() {
    log_info "Creating EC2 key pair: ${KEY_NAME}..."
    
    local key_file="${KEY_DIR}/${KEY_NAME}.pem"
    
    if aws ec2 create-key-pair \
        --key-name "${KEY_NAME}" \
        --query 'KeyMaterial' \
        --output text \
        --region "${REGION}" > "${key_file}" 2>> "${LOG_FILE}"; then
        
        chmod 400 "${key_file}"
        log_success "Key pair created and saved to ${key_file}"
        return 0
    else
        log_error "Failed to create key pair"
        return 1
    fi
}

get_default_vpc() {
    log "INFO" "Getting default VPC..."
    
    local vpc_id=$(aws ec2 describe-vpcs \
        --filters "Name=isDefault,Values=true" \
        --query 'Vpcs[0].VpcId' \
        --output text \
        --region "${REGION}" 2>> "${LOG_FILE}")
    
    if [[ -z "${vpc_id}" ]] || [[ "${vpc_id}" == "None" ]]; then
        log_error "No default VPC found"
        exit 1
    fi
    
    log "SUCCESS" "Default VPC: ${vpc_id}"
    echo "${vpc_id}"
}

get_security_group() {
    local vpc_id="$1"
    
    local sg_id=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=${vpc_id}" "Name=group-name,Values=default" \
        --query 'SecurityGroups[0].GroupId' \
        --output text \
        --region "${REGION}" 2>> "${LOG_FILE}")
    
    # Log to file only, not to stdout to avoid interfering with return value
    log "SUCCESS" "Using security group: ${sg_id}"
    echo "${sg_id}"
}

launch_ec2_instance() {
    local ami_id="$1"
    local sg_id="$2"
    
    log "INFO" "Launching EC2 instance..."
    
    local instance_id=$(aws ec2 run-instances \
        --image-id "${ami_id}" \
        --instance-type "${INSTANCE_TYPE}" \
        --key-name "${KEY_NAME}" \
        --security-group-ids "${sg_id}" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=AutomationLab-Instance},{Key=Project,Value=${PROJECT_TAG}},{Key=CreatedBy,Value=create_ec2.sh}]" \
        --query 'Instances[0].InstanceId' \
        --output text \
        --region "${REGION}" 2>> "${LOG_FILE}")
    
    if [[ -z "${instance_id}" ]] || [[ "${instance_id}" == "None" ]]; then
        log_error "Failed to launch EC2 instance"
        exit 1
    fi
    
    log "SUCCESS" "Instance launched with ID: ${instance_id}"
    echo "${instance_id}"
}

wait_for_instance() {
    local instance_id="$1"
    
    log_info "Waiting for instance to be in running state..."
    
    if aws ec2 wait instance-running \
        --instance-ids "${instance_id}" \
        --region "${REGION}" 2>> "${LOG_FILE}"; then
        log_success "Instance is now running"
        return 0
    else
        log_error "Timeout waiting for instance to run"
        return 1
    fi
}

get_instance_details() {
    local instance_id="$1"
    
    log_info "Fetching instance details..."
    
    aws ec2 describe-instances \
        --instance-ids "${instance_id}" \
        --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress,State.Name]' \
        --output text \
        --region "${REGION}"
}

save_instance_info() {
    local instance_id="$1"
    local public_ip="$2"
    local private_ip="$3"
    local ami_id="$4"
    
    cat > "${INFO_FILE}" << EOF
EC2 Instance Information
========================
Instance ID: ${instance_id}
Public IP: ${public_ip}
Private IP: ${private_ip}
Key Pair: ${KEY_NAME}
Key File: ${KEY_NAME}.pem
Instance Type: ${INSTANCE_TYPE}
AMI ID: ${ami_id}
Region: ${REGION}
Created: $(date)
Log File: ${LOG_FILE}

SSH Command:
ssh -i ${KEY_DIR}/${KEY_NAME}.pem ec2-user@${public_ip}
EOF
    
    log_success "Instance information saved to ${INFO_FILE}"
}

print_summary() {
    local instance_id="$1"
    local public_ip="$2"
    local private_ip="$3"
    local state="$4"
    local ami_id="$5"
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}EC2 Instance Created Successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "Instance ID:     ${GREEN}${instance_id}${NC}"
    echo -e "Public IP:       ${GREEN}${public_ip}${NC}"
    echo -e "Private IP:      ${GREEN}${private_ip}${NC}"
    echo -e "State:           ${GREEN}${state}${NC}"
    echo -e "Key Pair:        ${GREEN}${KEY_NAME}${NC}"
    echo -e "Key File:        ${GREEN}${KEY_NAME}.pem${NC}"
    echo -e "Instance Type:   ${GREEN}${INSTANCE_TYPE}${NC}"
    echo -e "AMI ID:          ${GREEN}${ami_id}${NC}"
    echo -e "Region:          ${GREEN}${REGION}${NC}"
    echo -e "Log File:        ${GREEN}${LOG_FILE}${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}To connect to your instance:${NC}"
    echo -e "ssh -i ${KEY_DIR}/${KEY_NAME}.pem ec2-user@${public_ip}"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}EC2 Instance Creation Script${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    log_info "Starting EC2 instance creation process"
    log_info "Log file: ${LOG_FILE}"
    
    # Validations
    check_aws_cli
    check_aws_credentials
    validate_region
    
    # Get required information
    print_info "Fetching latest Amazon Linux 2 AMI..."
    local AMI_ID=$(get_latest_ami)
    print_success "AMI ID: ${AMI_ID}"
    
    print_info "Getting default VPC..."
    local VPC_ID=$(get_default_vpc)
    print_success "Default VPC: ${VPC_ID}"
    
    print_info "Finding security group..."
    local SECURITY_GROUP=$(get_security_group "${VPC_ID}")
    print_success "Security group: ${SECURITY_GROUP}"
    
    # Create resources
    create_key_pair || exit 1
    
    print_info "Launching EC2 instance..."
    INSTANCE_ID=$(launch_ec2_instance "${AMI_ID}" "${SECURITY_GROUP}")
    print_success "Instance launched with ID: ${INSTANCE_ID}"
    
    wait_for_instance "${INSTANCE_ID}" || exit 1
    
    # Get instance details
    local instance_info=$(get_instance_details "${INSTANCE_ID}")
    local PUBLIC_IP=$(echo "${instance_info}" | awk '{print $1}')
    local PRIVATE_IP=$(echo "${instance_info}" | awk '{print $2}')
    local STATE=$(echo "${instance_info}" | awk '{print $3}')
    
    # Save and display results
    save_instance_info "${INSTANCE_ID}" "${PUBLIC_IP}" "${PRIVATE_IP}" "${AMI_ID}"
    print_summary "${INSTANCE_ID}" "${PUBLIC_IP}" "${PRIVATE_IP}" "${STATE}" "${AMI_ID}"
    
    log_success "EC2 instance creation completed successfully"
}

# Run main function
main "$@"


