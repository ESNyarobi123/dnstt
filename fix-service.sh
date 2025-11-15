#!/bin/bash

# Quick Fix Script - Create dnstt-server.service if missing
# Run: sudo bash fix-service.sh

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
INSTALL_DIR="/opt/skynet"
CONFIG_DIR="/etc/skynet"
LOG_DIR="/var/log/skynet"
SERVICE_FILE="/etc/systemd/system/dnstt-server.service"

print_info "Checking if service file exists..."

if [ -f "$SERVICE_FILE" ]; then
    print_warning "Service file already exists at: $SERVICE_FILE"
    read -p "Do you want to recreate it? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Keeping existing service file"
        exit 0
    fi
    print_info "Backing up existing service file..."
    cp "$SERVICE_FILE" "${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Check if dnstt-server binary exists
if [ ! -f "$INSTALL_DIR/dnstt-server" ]; then
    print_error "dnstt-server binary not found at: $INSTALL_DIR/dnstt-server"
    print_info "Please run the installation script first: sudo ./install.sh"
    exit 1
fi

# Check if keys exist
if [ ! -f "$CONFIG_DIR/privatekey.txt" ] || [ ! -f "$CONFIG_DIR/publickey.txt" ]; then
    print_warning "Keys not found. Generating keys..."
    if [ -f "$INSTALL_DIR/dnstt-server" ]; then
        "$INSTALL_DIR/dnstt-server" \
            -gen-key \
            -privkey-file "$CONFIG_DIR/privatekey.txt" \
            -pubkey-file "$CONFIG_DIR/publickey.txt" 2>/dev/null || {
            print_error "Failed to generate keys"
            exit 1
        }
        chmod 600 "$CONFIG_DIR/privatekey.txt"
        chmod 644 "$CONFIG_DIR/publickey.txt"
        print_success "Keys generated"
    else
        print_error "Cannot generate keys - dnstt-server not found"
        exit 1
    fi
fi

# Create setup-tun.sh if not exists
if [ ! -f "$INSTALL_DIR/setup-tun.sh" ]; then
    print_info "Creating setup-tun.sh script..."
    cat > "$INSTALL_DIR/setup-tun.sh" <<'TUNEOF'
#!/bin/bash
# Setup TUN interface for dnstt

if ! ip link show tun0 &>/dev/null; then
    ip tuntap add mode tun dev tun0
    ip addr add 10.0.0.1/24 dev tun0
    ip link set tun0 up
fi
TUNEOF
    chmod +x "$INSTALL_DIR/setup-tun.sh"
    print_success "setup-tun.sh created"
fi

# Create service file
print_info "Creating service file at: $SERVICE_FILE"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=DNS Tunnel Server (SKY NET SOLUTION)
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStartPre=/bin/bash -c 'if ! ip link show tun0 &>/dev/null; then ip tuntap add mode tun dev tun0 && ip addr add 10.0.0.1/24 dev tun0 && ip link set tun0 up; fi'
ExecStart=$INSTALL_DIR/dnstt-server -udp :53 \\
    -privkey-file $CONFIG_DIR/privatekey.txt \\
    -pubkey-file $CONFIG_DIR/publickey.txt \\
    -tun-dev tun0 \\
    -tun-addr 10.0.0.1/24 \\
    -tun-dns 8.8.8.8:53
Restart=always
RestartSec=5
StandardOutput=append:$LOG_DIR/dnstt.log
StandardError=append:$LOG_DIR/dnstt-error.log
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Verify file was created
if [ ! -f "$SERVICE_FILE" ]; then
    print_error "Failed to create service file!"
    exit 1
fi

print_success "Service file created successfully"

# Reload systemd
print_info "Reloading systemd daemon..."
systemctl daemon-reload

# Enable service
print_info "Enabling service..."
systemctl enable dnstt-server.service

# Start service
print_info "Starting service..."
systemctl start dnstt-server.service

sleep 2

# Check status
if systemctl is-active --quiet dnstt-server.service; then
    print_success "Service is running!"
    echo ""
    print_info "Service status:"
    systemctl status dnstt-server.service --no-pager -l
else
    print_warning "Service may not be running. Check status:"
    echo "  systemctl status dnstt-server"
    echo "  journalctl -u dnstt-server -n 50"
fi

echo ""
print_success "Service file created and configured!"
print_info "Location: $SERVICE_FILE"
print_info "You can now use: systemctl status dnstt-server"

