#!/bin/bash

# Audit Rules Validation and Testing Script
VERSION="1.1.0"
# Default configuration
AUDIT_RULES_FILE="/etc/audit/audit.rules"
VERBOSE=0
LOG_FILE="/var/log/audit-rules-check.log"

# Logging functions
log_error() {
    echo "[ERROR] $1" >&2
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}
log_info() {
    [[ $VERBOSE -eq 1 ]] && echo "[INFO] $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

# Usage instructions
usage() {
    cat << EOF
Audit Rules Checker v${VERSION}
Usage: $0 [OPTIONS]
Options:
    -f, --file FILE     Specify alternate audit rules file
    -v, --verbose       Enable verbose output
    -h, --help          Display this help message
EOF
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Validate auditd prerequisites
check_auditd_prerequisites() {
    if ! command_exists auditd || ! command_exists auditctl; then
        log_error "auditd or auditctl is not installed. Please install auditd."
        exit 1
    }
    if ! systemctl is-active --quiet auditd.service; then
        log_info "auditd service is not running. Attempting to start..."
        sudo systemctl start auditd.service
        sleep 2
        
        if ! systemctl is-active --quiet auditd.service; then
            log_error "Failed to start auditd service. Check logs: sudo journalctl -xe"
            exit 1
        fi
    fi
    log_info "auditd service is running."
}

# Enhanced rule validation
validate_rule() {
    local rule="$1"
    if [[ -z "$rule" || "$rule" =~ ^# ]]; then
        return 1
    fi
    if [[ "$rule" =~ ^(-a|-w)\s+ ]]; then
        local rule_type=$(echo "$rule" | awk '{print $1}')
        case "$rule_type" in
            -w)
                local file_path=$(echo "$rule" | awk '{print $2}')
                [[ -e "$file_path" ]] || {
                    log_error "File does not exist: $file_path"
                    return 1
                }
                ;;
            -a)
                [[ "$rule" =~ -S\s+([a-zA-Z0-9_]+) ]] || {
                    log_error "Invalid syscall rule: $rule"
                    return 1
                }
                ;;
        esac
        log_info "Valid rule: $rule"
        return 0
    fi
    log_error "Invalid rule format: $rule"
    return 1
}

# Test rule enforcement
test_rule_enforcement() {
    local rule="$1"
    local TEST_FILE=$(mktemp)
    trap 'rm -f "$TEST_FILE"' EXIT
    if [[ "$rule" =~ -k\s+([a-zA-Z0-9_-]+) ]]; then
        local key="${BASH_REMATCH[1]}"
    else
        log_error "Rule has no valid key: $rule"
        return 1
    fi
    log_info "Generating test event for rule: $rule"
    case "$rule" in
        *-w*)
            local file_path=$(echo "$rule" | awk '{print $2}')
            echo "Test event for $key" | sudo tee -a "$file_path" >/dev/null
            ;;
        *-a*)
            local syscall=$(echo "$rule" | grep -oP '(?<=-S )\w+')
            case "$syscall" in
                open) sudo touch "$TEST_FILE" ;;
                execve) /usr/bin/true ;;
                chmod) sudo chmod 0777 "$TEST_FILE" ;;
                unlink) sudo rm -f "$TEST_FILE" && sudo touch "$TEST_FILE" ;;
                *) 
                    log_error "Unsupported syscall for testing: $syscall"
                    return 1 
                    ;;
            esac
            ;;
    esac
    sleep 2
    local log_result=$(sudo ausearch -k "$key" -ts recent --format text 2>/dev/null)
    if [[ -z "$log_result" ]]; then
        log_error "Rule NOT enforced: $rule"
        return 1
    else
        log_info "Rule ENFORCED: $rule"
        return 0
    fi
}

# Main script execution
main() {
    # Parse command-line arguments
    local TEMP
    TEMP=$(getopt -o f:vh --long file:,verbose,help -n "$0" -- "$@")
    
    if [ $? != 0 ]; then
        usage
        exit 1
    fi
    eval set -- "$TEMP"
    while true; do
        case "$1" in
            -f|--file)
                AUDIT_RULES_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                log_error "Internal error!"
                exit 1
                ;;
        esac
    done
    
    # Prerequisite checks
    check_auditd_prerequisites
    
    # Validate rules file
    if [[ ! -f "$AUDIT_RULES_FILE" ]]; then
        log_error "Audit rules file not found: $AUDIT_RULES_FILE"
        exit 1
    fi
    log_info "Checking audit rules in $AUDIT_RULES_FILE..."
    
    # Counters
    local TOTAL_RULES=0
    local VALID_RULES=0
    local ENFORCED_RULES=0
    
    # Process rules
    while IFS= read -r rule; do
        TOTAL_RULES=$((TOTAL_RULES + 1))
        if validate_rule "$rule"; then
            VALID_RULES=$((VALID_RULES + 1))
            if test_rule_enforcement "$rule"; then
                ENFORCED_RULES=$((ENFORCED_RULES + 1))
            fi
        fi
    done < "$AUDIT_RULES_FILE"
    
    # Summary
    echo "----------------------------------------"
    echo "Audit Rules Check v${VERSION} Completed"
    echo "Total rules checked: $TOTAL_RULES"
    echo "Valid rules: $VALID_RULES"
    echo "Enforced rules: $ENFORCED_RULES"
    echo "Detailed log: $LOG_FILE"
    echo "----------------------------------------"
}

# Execute main with all arguments
main "$@"
