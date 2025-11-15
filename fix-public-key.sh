#!/bin/bash

# Fix Public Key Format Script
# This script cleans and fixes the public key format
# Run: sudo bash fix-public-key.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

# Configuration
CONFIG_DIR="/etc/skynet"
INSTALL_DIR="/opt/skynet"

print_info "Fixing public key format..."

# Check if public key file exists
if [ ! -f "$CONFIG_DIR/publickey.txt" ]; then
    print_error "Public key file not found at: $CONFIG_DIR/publickey.txt"
    print_info "Please generate a new key first using: skynet-menu (option 4)"
    exit 1
fi

# Read and clean the key
print_info "Reading current public key..."
CURRENT_KEY=$(cat "$CONFIG_DIR/publickey.txt")
print_info "Current key (raw): $CURRENT_KEY"

# Clean the key - remove all whitespace/newlines, keep only hex characters
CLEANED_KEY=$(echo "$CURRENT_KEY" | tr -d '\n\r\t ' | sed 's/[^0-9a-fA-F]//g')

print_info "Cleaned key: $CLEANED_KEY"
print_info "Key length: ${#CLEANED_KEY} characters"

# Verify key length (should be exactly 44 hex characters)
if [ ${#CLEANED_KEY} -ne 44 ]; then
    print_error "Public key has invalid length: ${#CLEANED_KEY} (expected: 44)"
    print_warning "The key may be corrupted or invalid"
    echo ""
    read -p "Do you want to generate a new key? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Generating new key..."
        if [ -f "$INSTALL_DIR/dnstt-server" ]; then
            # Backup old keys
            if [ -f "$CONFIG_DIR/privatekey.txt" ]; then
                mv "$CONFIG_DIR/privatekey.txt" "$CONFIG_DIR/privatekey.txt.backup.$(date +%Y%m%d_%H%M%S)"
            fi
            mv "$CONFIG_DIR/publickey.txt" "$CONFIG_DIR/publickey.txt.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Generate new keys
            "$INSTALL_DIR/dnstt-server" \
                -gen-key \
                -privkey-file "$CONFIG_DIR/privatekey.txt" \
                -pubkey-file "$CONFIG_DIR/publickey.txt" 2>/dev/null || {
                print_error "Failed to generate new keys"
                exit 1
            }
            
            # Clean and save
            NEW_KEY=$(cat "$CONFIG_DIR/publickey.txt" | tr -d '\n\r\t ' | sed 's/[^0-9a-fA-F]//g')
            if [ ${#NEW_KEY} -eq 44 ]; then
                echo -n "$NEW_KEY" > "$CONFIG_DIR/publickey.txt"
                chmod 600 "$CONFIG_DIR/privatekey.txt"
                chmod 644 "$CONFIG_DIR/publickey.txt"
                print_success "New key generated successfully: $NEW_KEY"
            else
                print_error "Generated key has invalid length: ${#NEW_KEY}"
                exit 1
            fi
        else
            print_error "dnstt-server binary not found at: $INSTALL_DIR/dnstt-server"
            exit 1
        fi
    else
        print_info "Keeping existing key (may not work with client)"
        exit 1
    fi
else
    # Key length is correct, just clean and save it
    print_info "Key length is correct, cleaning format..."
    echo -n "$CLEANED_KEY" > "$CONFIG_DIR/publickey.txt"
    chmod 644 "$CONFIG_DIR/publickey.txt"
    print_success "Public key fixed and saved!"
    print_info "New key: $CLEANED_KEY"
    print_info "Key length: ${#CLEANED_KEY} characters (correct)"
fi

echo ""
print_success "Public key is now in correct format!"
print_info "You can now use this key in your client app:"
echo -e "${GREEN}$(cat "$CONFIG_DIR/publickey.txt")${NC}"
echo ""

