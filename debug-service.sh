#!/bin/bash

# Debug and Fix dnstt-server Service Script
# Run: sudo bash debug-service.sh

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

echo ""
print_info "=== DNSTT-SERVER SERVICE DEBUGGER ==="
echo ""

# 1. Check if dnstt-server binary exists
print_info "1. Checking dnstt-server binary..."
if [ -f "$INSTALL_DIR/dnstt-server" ]; then
    if [ -x "$INSTALL_DIR/dnstt-server" ]; then
        print_success "Binary exists and is executable: $INSTALL_DIR/dnstt-server"
        # Test if binary works
        if "$INSTALL_DIR/dnstt-server" -h >/dev/null 2>&1 || "$INSTALL_DIR/dnstt-server" --help >/dev/null 2>&1; then
            print_success "Binary responds to help command"
        else
            print_warning "Binary may not be working correctly"
        fi
    else
        print_error "Binary exists but is not executable!"
        chmod +x "$INSTALL_DIR/dnstt-server"
        print_info "Made binary executable"
    fi
else
    print_error "Binary not found at: $INSTALL_DIR/dnstt-server"
    exit 1
fi

# 2. Check keys
print_info "2. Checking keys..."
if [ -f "$CONFIG_DIR/privatekey.txt" ] && [ -f "$CONFIG_DIR/publickey.txt" ]; then
    print_success "Keys exist"
    PRIV_SIZE=$(stat -c%s "$CONFIG_DIR/privatekey.txt" 2>/dev/null || echo "0")
    PUB_SIZE=$(stat -c%s "$CONFIG_DIR/publickey.txt" 2>/dev/null || echo "0")
    print_info "Private key size: $PRIV_SIZE bytes"
    print_info "Public key size: $PUB_SIZE bytes"
    
    if [ "$PRIV_SIZE" -lt 10 ] || [ "$PUB_SIZE" -lt 10 ]; then
        print_error "Keys appear to be too small or corrupted!"
        print_info "Regenerating keys..."
        "$INSTALL_DIR/dnstt-server" \
            -gen-key \
            -privkey-file "$CONFIG_DIR/privatekey.txt" \
            -pubkey-file "$CONFIG_DIR/publickey.txt" 2>/dev/null || {
            print_error "Failed to regenerate keys"
            exit 1
        }
        chmod 600 "$CONFIG_DIR/privatekey.txt"
        chmod 644 "$CONFIG_DIR/publickey.txt"
        print_success "Keys regenerated"
    fi
else
    print_error "Keys not found!"
    print_info "Generating keys..."
    mkdir -p "$CONFIG_DIR"
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
fi

# 3. Check port 53
print_info "3. Checking port 53..."
if netstat -tuln 2>/dev/null | grep -q ":53 " || ss -tuln 2>/dev/null | grep -q ":53 "; then
    print_warning "Port 53 is already in use!"
    print_info "Checking what's using port 53..."
    if command -v lsof >/dev/null 2>&1; then
        lsof -i :53 2>/dev/null || true
    elif command -v fuser >/dev/null 2>&1; then
        fuser 53/udp 2>/dev/null || true
    fi
    
    # Check if it's systemd-resolved
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        print_warning "systemd-resolved is running on port 53!"
        print_info "Stopping systemd-resolved..."
        systemctl stop systemd-resolved 2>/dev/null || true
        systemctl disable systemd-resolved 2>/dev/null || true
        print_success "systemd-resolved stopped"
    fi
    
    # Check if it's bind9 or named
    if systemctl is-active --quiet bind9 2>/dev/null || systemctl is-active --quiet named 2>/dev/null; then
        print_warning "BIND/DNS server is running on port 53!"
        print_info "You may need to stop it: systemctl stop bind9"
    fi
else
    print_success "Port 53 is available"
fi

# 4. Check TUN interface
print_info "4. Checking TUN interface..."
if ip link show tun0 >/dev/null 2>&1; then
    print_success "TUN interface tun0 exists"
    if ip addr show tun0 | grep -q "10.0.0.1"; then
        print_success "TUN interface has correct IP (10.0.0.1/24)"
    else
        print_warning "TUN interface exists but may not have correct IP"
    fi
else
    print_warning "TUN interface tun0 does not exist"
    print_info "Creating TUN interface..."
    if [ -f "$INSTALL_DIR/setup-tun.sh" ]; then
        bash "$INSTALL_DIR/setup-tun.sh"
        print_success "TUN interface created"
    else
        print_error "setup-tun.sh not found!"
        # Create it manually
        ip tuntap add mode tun dev tun0 2>/dev/null || true
        ip addr add 10.0.0.1/24 dev tun0 2>/dev/null || true
        ip link set tun0 up 2>/dev/null || true
        print_info "TUN interface created manually"
    fi
fi

# 5. Check setup-tun.sh script
print_info "5. Checking setup-tun.sh script..."
if [ -f "$INSTALL_DIR/setup-tun.sh" ]; then
    if [ -x "$INSTALL_DIR/setup-tun.sh" ]; then
        print_success "setup-tun.sh exists and is executable"
    else
        print_warning "setup-tun.sh exists but is not executable"
        chmod +x "$INSTALL_DIR/setup-tun.sh"
        print_info "Made setup-tun.sh executable"
    fi
else
    print_warning "setup-tun.sh not found, creating it..."
    mkdir -p "$INSTALL_DIR"
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

# 6. Check service file
print_info "6. Checking service file..."
if [ -f "$SERVICE_FILE" ]; then
    print_success "Service file exists: $SERVICE_FILE"
else
    print_error "Service file not found!"
    exit 1
fi

# 7. Test command manually
print_info "7. Testing dnstt-server command manually..."
print_info "Running test command (will timeout after 3 seconds)..."
timeout 3 "$INSTALL_DIR/dnstt-server" \
    -udp :53 \
    -mtu 1800 \
    -privkey-file "$CONFIG_DIR/privatekey.txt" \
    -pubkey-file "$CONFIG_DIR/publickey.txt" \
    -tun-dev tun0 \
    -tun-addr 10.0.0.1/24 \
    -tun-dns 8.8.8.8:53 2>&1 || EXIT_CODE=$?

if [ "${EXIT_CODE:-0}" -eq 124 ]; then
    print_success "Command started successfully (timeout is normal)"
elif [ "${EXIT_CODE:-0}" -eq 2 ]; then
    print_error "Command failed with exit code 2"
    print_info "This usually means:"
    print_info "  - Port 53 is already in use"
    print_info "  - Keys are invalid"
    print_info "  - TUN interface issue"
    print_info "  - Permission issue"
elif [ "${EXIT_CODE:-0}" -ne 0 ]; then
    print_warning "Command exited with code: ${EXIT_CODE}"
else
    print_success "Command executed successfully"
fi

# 8. Check logs
print_info "8. Checking service logs..."
if [ -f "$LOG_DIR/dnstt-error.log" ]; then
    print_info "Last 20 lines of error log:"
    tail -n 20 "$LOG_DIR/dnstt-error.log" 2>/dev/null || print_warning "Could not read error log"
    echo ""
fi

if [ -f "$LOG_DIR/dnstt.log" ]; then
    print_info "Last 10 lines of log:"
    tail -n 10 "$LOG_DIR/dnstt.log" 2>/dev/null || print_warning "Could not read log"
    echo ""
fi

# 9. Check journalctl
print_info "9. Checking systemd journal..."
print_info "Last 15 lines from journalctl:"
journalctl -u dnstt-server -n 15 --no-pager 2>/dev/null || print_warning "Could not read journal"
echo ""

# 10. Recommendations
echo ""
print_info "=== RECOMMENDATIONS ==="
echo ""

# Check if port is still in use
if netstat -tuln 2>/dev/null | grep -q ":53 " || ss -tuln 2>/dev/null | grep -q ":53 "; then
    print_warning "Port 53 is still in use!"
    print_info "Try stopping other DNS services:"
    print_info "  sudo systemctl stop systemd-resolved"
    print_info "  sudo systemctl stop bind9"
    print_info "  sudo systemctl stop named"
    echo ""
fi

print_info "To restart the service:"
print_info "  sudo systemctl daemon-reload"
print_info "  sudo systemctl restart dnstt-server"
print_info "  sudo systemctl status dnstt-server"
echo ""

print_info "To view real-time logs:"
print_info "  sudo journalctl -u dnstt-server -f"
print_info "  sudo tail -f $LOG_DIR/dnstt-error.log"
echo ""

print_success "Debug check completed!"

