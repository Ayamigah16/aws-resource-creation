#!/bin/bash

################################################################################
# Script: cleanup_resources.sh
# Purpose: Clean up all AWS resources created by automation scripts
# Author: DevOps Automation Lab
# Date: December 23, 2025
################################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
PROJECT_TAG="aws-resource-creation"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
DRY_RUN=false

# Output directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$(dirname "${SCRIPT_DIR}")/outputs"
LOG_DIR="${OUTPUT_DIR}/logs"
KEY_DIR="${OUTPUT_DIR}/keys"
INFO_DIR="${OUTPUT_DIR}/info"
SAMPLE_DIR="${OUTPUT_DIR}/samples"

mkdir -p "${LOG_DIR}" "${KEY_DIR}" "${INFO_DIR}" "${SAMPLE_DIR}"

LOG_FILE="${LOG_DIR}/cleanup_$(date +%Y%m%d_%H%M%S).log"

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
}

log_success() {
    log "SUCCESS" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_warning() {
    log "WARNING" "$@"
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

print_warning() {
    echo -e "${BLUE}⚠ $1${NC}"
}

################################################################################
# Validation Functions
################################################################################

check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
}

check_aws_credentials() {
    print_info "Verifying AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured properly."
        echo "Please run: aws configure"
        exit 1
    fi
    print_success "AWS credentials verified"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --region)
                REGION="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dry-run         Preview what would be deleted without actual deletion"
    echo "  --region REGION   Specify AWS region (default: ${REGION})"
    echo "  --help, -h        Show this help message"
}

confirm_deletion() {
    if [[ "${DRY_RUN}" == "false" ]]; then
        echo -e "${RED}WARNING: This will delete all resources tagged with Project=${PROJECT_TAG}${NC}"
        echo -e "${RED}This action cannot be undone!${NC}"
        echo ""
        read -p "Are you sure you want to continue? (yes/no): " CONFIRM
        
        if [[ "${CONFIRM}" != "yes" ]]; then
            echo "Cleanup cancelled."
            exit 0
        fi
        echo ""
    fi
}

################################################################################
# EC2 Cleanup Functions
################################################################################

cleanup_ec2_instances() {
    log_info "Searching for EC2 instances with tag Project=${PROJECT_TAG}..."
    print_info "Searching for EC2 instances with tag Project=${PROJECT_TAG}..."
    
    local instance_ids=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=${PROJECT_TAG}" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text \
        --region "${REGION}" 2>> "${LOG_FILE}")
    
    if [[ -z "${instance_ids}" ]]; then
        log_warning "No EC2 instances found with tag Project=${PROJECT_TAG}"
        print_warning "No EC2 instances found with tag Project=${PROJECT_TAG}"
        return 0
    fi
    
    log_info "Found instances: ${instance_ids}"
    echo -e "${YELLOW}Found instances: ${instance_ids}${NC}"
    
    for instance_id in ${instance_ids}; do
        local instance_name=$(aws ec2 describe-instances \
            --instance-ids "${instance_id}" \
            --query 'Reservations[0].Instances[0].Tags[?Key==`Name`].Value' \
            --output text \
            --region "${REGION}" 2>> "${LOG_FILE}")
        
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "Would terminate instance: ${instance_id} (${instance_name})"
            print_info "Would terminate instance: ${instance_id} (${instance_name})"
        else
            log_info "Terminating instance: ${instance_id} (${instance_name})..."
            print_info "Terminating instance: ${instance_id} (${instance_name})..."
            
            if aws ec2 terminate-instances \
                --instance-ids "${instance_id}" \
                --region "${REGION}" &>> "${LOG_FILE}"; then
                log_success "Instance ${instance_id} termination initiated"
                print_success "Instance ${instance_id} termination initiated"
            else
                log_error "Failed to terminate instance ${instance_id}"
                print_error "Failed to terminate instance ${instance_id}"
            fi
        fi
    done
    
    if [[ "${DRY_RUN}" == "false" ]]; then
        log_info "Waiting for instances to terminate..."
        print_info "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated \
            --instance-ids ${instance_ids} \
            --region "${REGION}" 2>> "${LOG_FILE}" || true
        log_success "All instances terminated"
        print_success "All instances terminated"
    fi
}

cleanup_key_pairs() {
    log_info "Searching for key pairs with name pattern 'automation-lab-key-*'..."
    print_info "Searching for key pairs with name pattern 'automation-lab-key-*'..."
    
    local key_pairs=$(aws ec2 describe-key-pairs \
        --query 'KeyPairs[?starts_with(KeyName, `automation-lab-key-`)].KeyName' \
        --output text \
        --region "${REGION}" 2>> "${LOG_FILE}")
    
    if [[ -z "${key_pairs}" ]]; then
        log_warning "No key pairs found with pattern 'automation-lab-key-*'"
        print_warning "No key pairs found with pattern 'automation-lab-key-*'"
        return 0
    fi
    
    for key_name in ${key_pairs}; do
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "Would delete key pair: ${key_name}"
            print_info "Would delete key pair: ${key_name}"
        else
            log_info "Deleting key pair: ${key_name}..."
            print_info "Deleting key pair: ${key_name}..."
            
            if aws ec2 delete-key-pair \
                --key-name "${key_name}" \
                --region "${REGION}" &>> "${LOG_FILE}"; then
                log_success "Key pair ${key_name} deleted"
                print_success "Key pair ${key_name} deleted"
            else
                log_error "Failed to delete key pair ${key_name}"
                print_error "Failed to delete key pair ${key_name}"
            fi
            
            # Remove local .pem file if it exists
            if [[ -f "${key_name}.pem" ]]; then
                rm -f "${key_name}.pem"
                log_success "Local key file ${key_name}.pem removed"
                print_success "Local key file ${key_name}.pem removed"
            fi
        fi
    done
}

cleanup_security_groups() {
    log_info "Searching for security groups with tag Project=${PROJECT_TAG}..."
    print_info "Searching for security groups with tag Project=${PROJECT_TAG}..."
    
    local sg_ids=$(aws ec2 describe-security-groups \
        --filters "Name=tag:Project,Values=${PROJECT_TAG}" \
        --query 'SecurityGroups[*].GroupId' \
        --output text \
        --region "${REGION}" 2>> "${LOG_FILE}")
    
    if [[ -z "${sg_ids}" ]]; then
        log_warning "No security groups found with tag Project=${PROJECT_TAG}"
        print_warning "No security groups found with tag Project=${PROJECT_TAG}"
        return 0
    fi
    
    for sg_id in ${sg_ids}; do
        local sg_name=$(aws ec2 describe-security-groups \
            --group-ids "${sg_id}" \
            --query 'SecurityGroups[0].GroupName' \
            --output text \
            --region "${REGION}" 2>> "${LOG_FILE}")
        
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "Would delete security group: ${sg_id} (${sg_name})"
            print_info "Would delete security group: ${sg_id} (${sg_name})"
        else
            log_info "Deleting security group: ${sg_id} (${sg_name})..."
            print_info "Deleting security group: ${sg_id} (${sg_name})..."
            
            if aws ec2 delete-security-group \
                --group-id "${sg_id}" \
                --region "${REGION}" 2>> "${LOG_FILE}"; then
                log_success "Security group ${sg_id} deleted"
                print_success "Security group ${sg_id} deleted"
            else
                log_error "Failed to delete security group ${sg_id} (may be in use)"
                print_error "Failed to delete security group ${sg_id} (may be in use)"
            fi
        fi
    done
}

cleanup_s3_buckets() {
    log_info "Searching for S3 buckets with tag Project=${PROJECT_TAG}..."
    print_info "Searching for S3 buckets with tag Project=${PROJECT_TAG}..."
    
    # Get all buckets
    local all_buckets=$(aws s3api list-buckets --query 'Buckets[*].Name' --output text --region "${REGION}" 2>> "${LOG_FILE}")
    
    local matching_buckets=""
    
    for bucket in ${all_buckets}; do
        # Check if bucket has the Project tag
        local tags=$(aws s3api get-bucket-tagging --bucket "${bucket}" --region "${REGION}" 2>/dev/null || echo "")
        
        if echo "${tags}" | grep -q "\"Key\": \"Project\"" && echo "${tags}" | grep -q "\"Value\": \"${PROJECT_TAG}\""; then
            matching_buckets="${matching_buckets} ${bucket}"
        elif [[ "${bucket}" == automation-lab-bucket-* ]]; then
            # Also match by naming pattern
            matching_buckets="${matching_buckets} ${bucket}"
        fi
    done
    
    if [[ -z "${matching_buckets}" ]]; then
        log_warning "No S3 buckets found with tag Project=${PROJECT_TAG}"
        print_warning "No S3 buckets found with tag Project=${PROJECT_TAG}"
        return 0
    fi
    
    for bucket in ${matching_buckets}; do
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "Would delete S3 bucket: ${bucket} (including all contents)"
            print_info "Would delete S3 bucket: ${bucket} (including all contents)"
        else
            log_info "Deleting S3 bucket: ${bucket}..."
            print_info "Deleting S3 bucket: ${bucket}..."
            
            # Delete all objects
            log_info "Removing all objects from ${bucket}..."
            print_info "Removing all objects from ${bucket}..."
            aws s3 rm "s3://${bucket}" --recursive --region "${REGION}" &>> "${LOG_FILE}" || true
            
            # Delete all object versions
            log_info "Removing all object versions from ${bucket}..."
            aws s3api delete-objects \
                --bucket "${bucket}" \
                --delete "$(aws s3api list-object-versions \
                    --bucket "${bucket}" \
                    --query '{Objects: Versions[].{Key: Key, VersionId: VersionId}}' \
                    --region "${REGION}" 2>/dev/null)" \
                --region "${REGION}" &>> "${LOG_FILE}" 2>&1 || true
            
            # Delete delete markers
            aws s3api delete-objects \
                --bucket "${bucket}" \
                --delete "$(aws s3api list-object-versions \
                    --bucket "${bucket}" \
                    --query '{Objects: DeleteMarkers[].{Key: Key, VersionId: VersionId}}' \
                    --region "${REGION}" 2>/dev/null)" \
                --region "${REGION}" &>> "${LOG_FILE}" 2>&1 || true
            
            # Delete the bucket
            if aws s3api delete-bucket --bucket "${bucket}" --region "${REGION}" 2>> "${LOG_FILE}"; then
                log_success "S3 bucket ${bucket} deleted"
                print_success "S3 bucket ${bucket} deleted"
            else
                log_error "Failed to delete S3 bucket ${bucket}"
                print_error "Failed to delete S3 bucket ${bucket}"
            fi
        fi
    done
}

cleanup_local_files() {
    log_info "Cleaning up local information files..."
    print_info "Cleaning up local information files..."
    
    local file_count=0
    
    # Clean up info files
    if [[ -d "${INFO_DIR}" ]]; then
        for file in "${INFO_DIR}"/*.txt; do
            if [[ -f "${file}" ]]; then
                if [[ "${DRY_RUN}" == "true" ]]; then
                    log_info "Would delete: ${file}"
                    print_info "Would delete: ${file}"
                else
                    rm -f "${file}"
                    log_success "Removed: ${file}"
                    print_success "Removed: ${file}"
                    ((file_count++))
                fi
            fi
        done
    fi
    
    # Clean up sample files
    if [[ -d "${SAMPLE_DIR}" ]]; then
        for file in "${SAMPLE_DIR}"/*.txt; do
            if [[ -f "${file}" ]]; then
                if [[ "${DRY_RUN}" == "true" ]]; then
                    log_info "Would delete: ${file}"
                    print_info "Would delete: ${file}"
                else
                    rm -f "${file}"
                    log_success "Removed: ${file}"
                    print_success "Removed: ${file}"
                    ((file_count++))
                fi
            fi
        done
    fi
    
    # Clean up .pem files
    if [[ -d "${KEY_DIR}" ]]; then
        for pem_file in "${KEY_DIR}"/automation-lab-key-*.pem; do
            if [[ -f "${pem_file}" ]]; then
                if [[ "${DRY_RUN}" == "true" ]]; then
                    log_info "Would delete: ${pem_file}"
                    print_info "Would delete: ${pem_file}"
                else
                    rm -f "${pem_file}"
                    log_success "Removed: ${pem_file}"
                    print_success "Removed: ${pem_file}"
                    ((file_count++))
                fi
            fi
        done
    fi
    
    if [[ "${DRY_RUN}" == "false" && ${file_count} -gt 0 ]]; then
        log_success "Removed ${file_count} local file(s)"
        print_success "Removed ${file_count} local file(s)"
    elif [[ ${file_count} -eq 0 ]]; then
        log_info "No local files found to remove"
        print_info "No local files found to remove"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}AWS Resource Cleanup Script${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    
    log_info "Starting cleanup process"
    log_info "Log file: ${LOG_FILE}"
    
    # Parse arguments
    parse_arguments "$@"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        print_warning "DRY RUN MODE - No resources will be deleted"
        log_warning "DRY RUN MODE enabled"
        echo ""
    fi
    
    # Validations
    check_aws_cli
    check_aws_credentials
    echo ""
    
    # Confirmation
    confirm_deletion
    
    log_info "Starting cleanup for region: ${REGION}"
    echo -e "${YELLOW}Starting cleanup process...${NC}"
    echo ""
    
    # Execute cleanup functions
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}1. Cleaning up EC2 Instances${NC}"
    echo -e "${BLUE}========================================${NC}"
    cleanup_ec2_instances
    echo ""
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}2. Cleaning up Key Pairs${NC}"
    echo -e "${BLUE}========================================${NC}"
    cleanup_key_pairs
    echo ""
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}3. Cleaning up Security Groups${NC}"
    echo -e "${BLUE}========================================${NC}"
    cleanup_security_groups
    echo ""
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}4. Cleaning up S3 Buckets${NC}"
    echo -e "${BLUE}========================================${NC}"
    cleanup_s3_buckets
    echo ""
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}5. Cleaning up Local Files${NC}"
    echo -e "${BLUE}========================================${NC}"
    cleanup_local_files
    echo ""
    
    # Summary
    if [[ "${DRY_RUN}" == "true" ]]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Dry Run Complete!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "Run without --dry-run to actually delete resources"
        log_info "Dry run completed"
    else
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Cleanup Complete!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "All resources with tag ${GREEN}Project=${PROJECT_TAG}${NC} have been cleaned up"
        log_success "Cleanup completed successfully"
    fi
    echo -e "Log file: ${GREEN}${LOG_FILE}${NC}"
    echo ""
}


