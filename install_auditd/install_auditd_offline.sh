#!/bin/bash

# Function to check Ubuntu version
get_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "Unable to determine Ubuntu version."
        exit 1
    fi
}

# Determine Ubuntu version
UBUNTU_VERSION=$(get_ubuntu_version)

# Define package filenames based on Ubuntu version
case $UBUNTU_VERSION in
    24.04)
        LIBAUPARSE_PKG="libauparse0t64_3.1.2-2.1build1_amd64.deb"
        AUDITD_PKG="auditd_3.1.2-2.1build1_amd64.deb"
        ;;
    22.04)
        LIBAUPARSE_PKG="libauparse0_3.0.7-1build1_amd64.deb"
        AUDITD_PKG="auditd_3.0.7-1build1_amd64.deb"
        ;;
    20.04)
        LIBAUPARSE_PKG="libauparse0_2.8.5-2ubuntu6_amd64.deb"
        AUDITD_PKG="auditd_2.8.5-2ubuntu6_amd64.deb"
        ;;
    18.04)
        LIBAUPARSE_PKG="libauparse0_2.8.2-1ubuntu1_amd64.deb"
        AUDITD_PKG="auditd_2.8.2-1ubuntu1_amd64.deb"
        ;;
    16.04)
        LIBAUPARSE_PKG="libauparse0_2.4.5-1ubuntu2_amd64.deb"
        AUDITD_PKG="auditd_2.4.5-1ubuntu2_amd64.deb"
        ;;
    *)
        echo "Unsupported Ubuntu version: $UBUNTU_VERSION"
        exit 1
        ;;
esac

# Check if the required .deb files exist in the same directory
if [ ! -f "$LIBAUPARSE_PKG" ] || [ ! -f "$AUDITD_PKG" ]; then
    echo "Required .deb files not found in the script directory."
    echo "Please ensure the following files are present:"
    echo "1. $LIBAUPARSE_PKG"
    echo "2. $AUDITD_PKG"
    exit 1
fi

# Install libauparse0
echo "Installing $LIBAUPARSE_PKG..."
sudo dpkg -i "$LIBAUPARSE_PKG"
if [ $? -ne 0 ]; then
    echo "Failed to install $LIBAUPARSE_PKG. Resolving dependencies..."
    sudo apt-get install -f -y
fi

# Install auditd
echo "Installing $AUDITD_PKG..."
sudo dpkg -i "$AUDITD_PKG"
if [ $? -ne 0 ]; then
    echo "Failed to install $AUDITD_PKG. Resolving dependencies..."
    sudo apt-get install -f -y
fi

# Enable and start auditd service
echo "Enabling and starting auditd service..."
sudo systemctl enable auditd
sudo systemctl start auditd

# Verify installation
echo "Verifying installation..."
sudo systemctl status auditd

Install custom auditd rules
AUDIT_RULES_FILE="auditd_rules.conf"
AUDIT_RULES_PATH="/etc/audit/rules.d/audit.rules"

if [ -f "$AUDIT_RULES_FILE" ]; then
    echo "Installing custom auditd rules..."
    sudo cp "$AUDIT_RULES_FILE" "$AUDIT_RULES_PATH"
    sudo augenrules --load
    echo "Custom auditd rules installed and loaded."
else
    echo "Custom auditd rules file ($AUDIT_RULES_FILE) not found. Skipping rules installation."
fi

echo "auditd installation completed successfully!"
