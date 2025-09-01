#!/bin/bash

# Function to check audit logs for specific key and validate the presence of the log entry
check_audit_log() {
    local key=$1
    echo "Checking audit logs for key: $key"
    # Search for the key in the audit logs
    if sudo ausearch -k $key | grep -q "$key"; then
        echo "Audit log found for key: $key"
    else
        echo "No audit log found for key: $key"
        return 1
    fi
    return 0
}

# Function to simulate changes to /var/log
simulate_var_log_changes() {
    echo "Simulating changes to /var/log..."
    touch /var/log/testfile.log
    chmod +x /var/log/testfile.log
    rm /var/log/testfile.log
    if ! check_audit_log "audit-wazuh-log"; then
        echo "Validation failed for /var/log changes"
        return 1
    fi
}

# Function to simulate changes to /etc/login.defs
simulate_etc_login_defs_changes() {
    echo "Simulating changes to /etc/login.defs..."
    cp /etc/login.defs /tmp/login.defs.bak
    echo "TEST_CHANGE" >> /etc/login.defs
    mv /tmp/login.defs.bak /etc/login.defs
    if ! check_audit_log "audit-wazuh-login"; then
        echo "Validation failed for /etc/login.defs changes"
        return 1
    fi
}

# Function to simulate changes to /etc/security/faillock.conf
simulate_faillock_changes() {
    echo "Simulating changes to /etc/security/faillock.conf..."
    cp /etc/security/faillock.conf /tmp/faillock.conf.bak
    echo "TEST_CHANGE" >> /etc/security/faillock.conf
    mv /tmp/faillock.conf.bak /etc/security/faillock.conf
    if ! check_audit_log "audit-wazuh-faillock"; then
        echo "Validation failed for /etc/security/faillock.conf changes"
        return 1
    fi
}

# Function to simulate command execution by root user
simulate_root_command_execution() {
    echo "Simulating command execution by root user..."
    bash -c 'echo "Root command executed" > /tmp/root_command_test'
    rm /tmp/root_command_test
    if ! check_audit_log "audit-wazuh-c"; then
        echo "Validation failed for root command execution"
        return 1
    fi
}

# Function to simulate command execution by non-privileged users (this part can be skipped when running as root)
simulate_non_privileged_user_command_execution() {
    echo "Simulating command execution by non-privileged user..."
    echo "Non-privileged user command executed" > /tmp/non_privileged_command_test
    rm /tmp/non_privileged_command_test
    if ! check_audit_log "audit-wazuh-c"; then
        echo "Validation failed for non-privileged user command execution"
        return 1
    fi
}

# Function to simulate changes to sudoers files
simulate_sudoers_changes() {
    echo "Simulating changes to sudoers files..."
    cp /etc/sudoers /tmp/sudoers.bak
    visudo -c && echo "# TEST_CHANGE" >> /etc/sudoers.d/test
    mv /tmp/sudoers.bak /etc/sudoers
    rm /etc/sudoers.d/test
    if ! check_audit_log "scope"; then
        echo "Validation failed for sudoers file changes"
        return 1
    fi
}

# Function to simulate system locale changes
simulate_system_locale_changes() {
    echo "Simulating system locale changes..."
    cp /etc/issue /tmp/issue.bak
    echo "TEST_CHANGE" >> /etc/issue
    mv /tmp/issue.bak /etc/issue
    if ! check_audit_log "system-locale"; then
        echo "Validation failed for system locale changes"
        return 1
    fi
}

# Function to simulate identity changes
simulate_identity_changes() {
    echo "Simulating identity changes..."
    cp /etc/group /tmp/group.bak
    echo "testgroup:x:1001:" >> /etc/group
    mv /tmp/group.bak /etc/group
    if ! check_audit_log "identity"; then
        echo "Validation failed for identity changes"
        return 1
    fi
}

# Function to simulate session activities
simulate_session_activities() {
    echo "Simulating session activities..."
    # Simulate login/logout using `last`
    last -f /var/log/wtmp | grep -q "$(whoami)"
    if ! check_audit_log "session"; then
        echo "Validation failed for session activities"
        return 1
    fi
}

# Function to simulate login activities
simulate_login_activities() {
    echo "Simulating login activities..."
    # Simulate login activity
    lastlog | grep -q "$(whoami)"
    if ! check_audit_log "logins"; then
        echo "Validation failed for login activities"
        return 1
    fi
}

# Function to simulate MAC policy changes
simulate_mac_policy_changes() {
    echo "Simulating MAC policy changes..."
    cp /etc/apparmor.d/local/usr.bin.firefox /tmp/firefox.bak
    echo "# TEST_CHANGE" >> /etc/apparmor.d/local/usr.bin.firefox
    mv /tmp/firefox.bak /etc/apparmor.d/local/usr.bin.firefox
    if ! check_audit_log "MAC-policy"; then
        echo "Validation failed for MAC policy changes"
        return 1
    fi
}

# Function to simulate time changes
simulate_time_changes() {
    echo "Simulating time changes..."
    date --set="2023-01-01 00:00:00"
    hwclock --systohc
    if ! check_audit_log "timechange"; then
        echo "Validation failed for time changes"
        return 1
    fi
}

# Function to simulate usage of passwd command
simulate_passwd_command_usage() {
    echo "Simulating usage of passwd command..."
    echo -e "current_password\nnew_password\nnew_password" | passwd $(whoami)
    if ! check_audit_log "passwd_modification"; then
        echo "Validation failed for passwd command usage"
        return 1
    fi
}

# Function to simulate group management tools usage
simulate_group_management_tools_usage() {
    echo "Simulating usage of group management tools..."
    groupadd testgroup
    groupdel testgroup
    if ! check_audit_log "group_modification"; then
        echo "Validation failed for group management tools usage"
        return 1
    fi
}

# Function to simulate user management tools usage
simulate_user_management_tools_usage() {
    echo "Simulating usage of user management tools..."
    useradd testuser
    userdel testuser
    if ! check_audit_log "user_modification"; then
        echo "Validation failed for user management tools usage"
        return 1
    fi
}

# Function to simulate sudo su command
simulate_sudo_su() {
    echo "Simulating sudo su command..."
    su -c 'echo "Privilege escalation using sudo su"' > /dev/null
    if ! check_audit_log "sudo_exec"; then
        echo "Validation failed for sudo su command"
        return 1
    fi
}

# Main function to run tests
run_tests() {
    simulate_var_log_changes
    simulate_etc_login_defs_changes
    simulate_faillock_changes
    simulate_root_command_execution
    # Comment out or skip simulate_non_privileged_user_command_execution if running as root
    # simulate_non_privileged_user_command_execution
    simulate_sudoers_changes
    simulate_system_locale_changes
    simulate_identity_changes
    simulate_session_activities
    simulate_login_activities
    simulate_mac_policy_changes
    simulate_time_changes
    simulate_passwd_command_usage
    simulate_group_management_tools_usage
    simulate_user_management_tools_usage
    simulate_sudo_su
}

# Run tests
if run_tests; then
    echo "All tests passed successfully."
else
    echo "Some tests failed. Please review the output."
fi
