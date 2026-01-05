#!/bin/bash

################################################################################
# Script: create_security_group.sh
# Purpose: Automate Security Group creation with SSH and HTTP access
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
SG_NAME="devops-sg-$(date +%s)"
SG_DESCRIPTION="Security group for DevOps automation lab - SSH and HTTP access"
PROJECT_TAG="aws-resource-creation"
REGION="${AWS_DEFAULT_REGION:-eu-west-1}"

# Output directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$(dirname "${SCRIPT_DIR}")/outputs"
LOG_DIR="${OUTPUT_DIR}/logs"
INFO_DIR="${OUTPUT_DIR}/info"

mkdir -p "${LOG_DIR}" "${INFO_DIR}"

LOG_FILE="${LOG_DIR}/sg_creation_$(date +%Y%m%d_%H%M%S).log"
INFO_FILE="${INFO_DIR}/security_group_info.txt"

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
    
    if [[ -n "${SG_ID:-}" ]]; then
        log_error "Cleaning up security group: ${SG_ID}"
        aws ec2 delete-security-group --group-id "${SG_ID}" --region "${REGION}" 2>/dev/null || true
    fi
    
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

################################################################################
# Core Functions
################################################################################

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

create_security_group() {
    local vpc_id="$1"
    
    log "INFO" "Creating security group: ${SG_NAME}..."
    
    local sg_id=$(aws ec2 create-security-group \
        --group-name "${SG_NAME}" \
        --description "${SG_DESCRIPTION}" \
        --vpc-id "${vpc_id}" \
        --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${SG_NAME}},{Key=Project,Value=${PROJECT_TAG}},{Key=CreatedBy,Value=create_security_group.sh}]" \
        --query 'GroupId' \
        --output text \
        --region "${REGION}" 2>> "${LOG_FILE}")
    
    if [[ -z "${sg_id}" ]] || [[ "${sg_id}" == "None" ]]; then
        log_error "Failed to create security group"
        exit 1
    fi
    
    log "SUCCESS" "Security group created with ID: ${sg_id}"
    echo "${sg_id}"
}

add_ingress_rule() {
    local sg_id="$1"
    local port="$2"
    local protocol="${3:-tcp}"
    local cidr="${4:-0.0.0.0/0}"
    local description="$5"
    
    log_info "Adding ${description} rule (port ${port})..."
    
    if aws ec2 authorize-security-group-ingress \
        --group-id "${sg_id}" \
        --protocol "${protocol}" \
        --port "${port}" \
        --cidr "${cidr}" \
        --region "${REGION}" &>> "${LOG_FILE}"; then
        log_success "${description} access rule added (${cidr}:${port})"
        return 0
    else
        log_error "Failed to add ${description} rule"
        return 1
    fi
}

get_security_group_rules() {
    local sg_id="$1"
    
    log_info "Fetching security group rules..."
    
    aws ec2 describe-security-groups \
        --group-ids "${sg_id}" \
        --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]' \
        --output text \
        --region "${REGION}"
}

save_security_group_info() {
    local sg_id="$1"
    local vpc_id="$2"
    
    cat > "${INFO_FILE}" << EOF
Security Group Information
==========================
Security Group ID: ${sg_id}
Security Group Name: ${SG_NAME}
VPC ID: ${vpc_id}
Region: ${REGION}
Created: $(date)
Log File: ${LOG_FILE}

Inbound Rules:
--------------
EOF
    
    aws ec2 describe-security-groups \
        --group-ids "${sg_id}" \
        --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]' \
        --output text \
        --region "${REGION}" | while read protocol from_port to_port cidr; do
        echo "Protocol: ${protocol} | Port: ${from_port} | Source: ${cidr}" >> "${INFO_FILE}"
    done
    
    log_success "Security group information saved to ${INFO_FILE}"
}

print_summary() {
    local sg_id="$1"
    local vpc_id="$2"
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Security Group Created Successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "Security Group ID:   ${GREEN}${sg_id}${NC}"
    echo -e "Security Group Name: ${GREEN}${SG_NAME}${NC}"
    echo -e "VPC ID:              ${GREEN}${vpc_id}${NC}"
    echo -e "Region:              ${GREEN}${REGION}${NC}"
    echo -e "Log File:            ${GREEN}${LOG_FILE}${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Inbound Rules:${NC}"
    echo ""
}

display_rules() {
    local sg_id="$1"
    
    get_security_group_rules "${sg_id}" | while read protocol from_port to_port cidr; do
        if [[ "${protocol}" == "tcp" ]]; then
            case "${from_port}" in
                22)  SERVICE="SSH" ;;
                80)  SERVICE="HTTP" ;;
                443) SERVICE="HTTPS" ;;
                *)   SERVICE="Custom" ;;
            esac
            echo -e "  ${GREEN}✓${NC} Protocol: ${protocol} | Port: ${from_port} | Source: ${cidr} | Service: ${SERVICE}"
        fi
    done
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Security Group Creation Script${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    log_info "Starting security group creation process"
    log_info "Log file: ${LOG_FILE}"
    
    # Validations
    check_aws_cli
    check_aws_credentials
    
    # Get VPC
    print_info "Getting default VPC..."
    local VPC_ID=$(get_default_vpc)
    print_success "Default VPC: ${VPC_ID}"
    
    # Create security group
    print_info "Creating security group: ${SG_NAME}..."
    SG_ID=$(create_security_group "${VPC_ID}")
    print_success "Security group created with ID: ${SG_ID}"
    
    # Add ingress rules
    add_ingress_rule "${SG_ID}" 22 "tcp" "0.0.0.0/0" "SSH"
    add_ingress_rule "${SG_ID}" 80 "tcp" "0.0.0.0/0" "HTTP"
    add_ingress_rule "${SG_ID}" 443 "tcp" "0.0.0.0/0" "HTTPS"
    
    # Save and display results
    save_security_group_info "${SG_ID}" "${VPC_ID}"
    print_summary "${SG_ID}" "${VPC_ID}"
    display_rules "${SG_ID}"
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}To use this security group with EC2:${NC}"
    echo -e "aws ec2 run-instances --security-group-ids ${SG_ID} ..."
    echo ""
    
    log_success "Security group creation completed successfully"
}

# Run main function
main "$@"
