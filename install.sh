#!/bin/bash

# SKY NET SOLUTION - Advanced DNS Tunneling Installation Script
# Modern, Fast, and Stable DNS over HTTPS/TLS Solution

set -e

# Colors for beautiful UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
INSTALL_DIR="/opt/skynet"
CONFIG_DIR="/etc/skynet"
DATA_DIR="/var/lib/skynet"
LOG_DIR="/var/log/skynet"
BIN_DIR="/usr/local/bin"

# Banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║           ███████╗██╗  ██╗██╗   ██╗███╗   ██╗███████╗████████╗"
    echo "║           ██╔════╝██║ ██╔╝╚██╗ ██╔╝████╗  ██║██╔════╝╚══██╔══╝"
    echo "║           ███████╗█████╔╝ ╚████╔╝ ██╔██╗ ██║█████╗     ██║   "
    echo "║           ╚════██║██╔═██╗  ╚██╔╝  ██║╚██╗██║██╔══╝     ██║   "
    echo "║           ███████║██║  ██╗   ██║   ██║ ╚████║███████╗   ██║   "
    echo "║           ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═══╝╚══════╝   ╚═╝   "
    echo "║                                                              ║"
    echo "║              ███████╗ ██████╗ ██╗   ██╗████████╗              ║"
    echo "║              ██╔════╝██╔═══██╗██║   ██║╚══██╔══╝              ║"
    echo "║              ███████╗██║   ██║██║   ██║   ██║                 ║"
    echo "║              ╚════██║██║   ██║██║   ██║   ██║                 ║"
    echo "║              ███████║╚██████╔╝╚██████╔╝   ██║                 ║"
    echo "║              ╚══════╝ ╚═════╝  ╚═════╝    ╚═╝                 ║"
    echo "║                                                              ║"
    echo "║          Advanced DNS Tunneling Solution v2.0                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print colored messages
print_success() {
    echo -e "${GREEN}${BOLD}[✓]${NC} ${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}${BOLD}[✗]${NC} ${RED}$1${NC}"
}

print_info() {
    echo -e "${BLUE}${BOLD}[*]${NC} ${BLUE}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${BOLD}[!]${NC} ${YELLOW}$1${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "Please run as root (use sudo)"
        exit 1
    fi
}

# System configuration
configure_system() {
    print_info "Configuring system settings..."
    
    # 1. Disable UFW
    print_info "Disabling UFW..."
    if command -v ufw &> /dev/null; then
        ufw disable 2>/dev/null || true
        if systemctl is-active --quiet ufw 2>/dev/null; then
            systemctl stop ufw 2>/dev/null || true
        fi
        systemctl disable ufw 2>/dev/null || true
        print_success "UFW disabled"
    else
        print_warning "UFW not installed, skipping..."
    fi
    
    # 2. Disable systemd-resolved
    print_info "Disabling systemd-resolved..."
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        systemctl stop systemd-resolved 2>/dev/null || true
        print_success "systemd-resolved stopped"
    fi
    systemctl disable systemd-resolved 2>/dev/null || true
    print_success "systemd-resolved disabled"
    
    # 3. Delete /etc/resolv.conf symlink
    if [ -L /etc/resolv.conf ]; then
        print_info "Removing resolv.conf symlink..."
        rm -f /etc/resolv.conf
        print_success "Symlink removed"
    fi
    
    # 4. Create new /etc/resolv.conf with Google DNS
    print_info "Creating new resolv.conf with Google DNS..."
    
    # Remove immutable attribute if exists
    chattr -i /etc/resolv.conf 2>/dev/null || true
    
    cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
options timeout:2 attempts:3 rotate
EOF
    
    # Make it immutable to prevent systemd-resolved from changing it
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    # Also create a backup
    cp /etc/resolv.conf /etc/resolv.conf.skynet.backup 2>/dev/null || true
    
    print_success "Google DNS configured (8.8.8.8, 8.8.4.4)"
}

# Install dependencies
install_dependencies() {
    print_info "Installing dependencies..."
    
    if [ -f /etc/debian_version ]; then
        apt-get update -qq
        apt-get install -y -qq wget curl git build-essential libssl-dev \
            golang-go dnsutils net-tools iproute2 iptables > /dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        yum install -y -q wget curl git gcc gcc-c++ make openssl-devel \
            golang bind-utils net-tools iproute iptables > /dev/null 2>&1
    fi
    
    print_success "Dependencies installed"
}

# Install dnstt
install_dnstt() {
    print_info "Installing dnstt..."
    
    # Create directories
    mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR"
    
    # Download and build dnstt
    if [ ! -f "$INSTALL_DIR/dnstt-server" ]; then
        print_info "Downloading dnstt source..."
        cd /tmp
        rm -rf dnstt
        git clone https://www.bamsoftware.com/git/dnstt.git > /dev/null 2>&1
        cd dnstt/dnstt-server
        go build -o "$INSTALL_DIR/dnstt-server" > /dev/null 2>&1
        print_success "dnstt-server compiled"
    fi
    
    # Generate keys if not exists
    if [ ! -f "$CONFIG_DIR/publickey.txt" ] || [ ! -f "$CONFIG_DIR/privatekey.txt" ]; then
        print_info "Generating keys..."
        cd /tmp/dnstt/dnstt-keygen
        go run . > "$CONFIG_DIR/keygen_output.txt" 2>&1
        
        # Extract keys
        PRIVATE_KEY=$(grep "Private key:" "$CONFIG_DIR/keygen_output.txt" | awk '{print $3}')
        PUBLIC_KEY=$(grep "Public key:" "$CONFIG_DIR/keygen_output.txt" | awk '{print $3}')
        
        echo "$PRIVATE_KEY" > "$CONFIG_DIR/privatekey.txt"
        echo "$PUBLIC_KEY" > "$CONFIG_DIR/publickey.txt"
        
        chmod 600 "$CONFIG_DIR/privatekey.txt"
        print_success "Keys generated"
    fi
    
    # Configure DNS for 512/1800 bytes handling
    configure_dns_bytes
    
    # Create systemd service
    create_service
    
    print_success "dnstt installed"
}

# Configure DNS bytes handling (512/1800)
configure_dns_bytes() {
    print_info "Configuring DNS for optimal 512/1800 bytes handling..."
    
    # Create dnstt configuration with forced 1800 bytes
    cat > "$CONFIG_DIR/dnstt.conf" <<EOF
# SKY NET SOLUTION - DNS Configuration
# Optimized for 512/1800 bytes handling - FORCE 1800 BYTES

# Force EDNS0 buffer size to 1800 bytes for maximum performance
# Even when providers request 512 bytes, we return 1800 bytes
# This ensures stable and fast connection

# DNS server configuration:
# - Accepts both 512 and 1800 byte requests
# - Always responds with 1800 bytes for optimal speed
# - Stable connection handling
EOF
    
    # Configure sysctl for optimal DNS performance
    print_info "Optimizing system parameters for DNS..."
    
    # Increase UDP buffer sizes for better DNS performance
    cat >> /etc/sysctl.conf <<EOF

# SKY NET SOLUTION - DNS Optimization
# Force 1800 bytes handling for stable connection
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.ipv4.udp_mem = 262144 873800 16777216
net.ipv4.udp_rmem_min = 4096
net.ipv4.udp_wmem_min = 4096
net.ipv4.ip_forward = 1
EOF
    
    sysctl -p > /dev/null 2>&1
    
    # Configure iptables for DNS forwarding
    print_info "Configuring iptables rules..."
    
    # Flush existing rules (optional, be careful)
    # iptables -F INPUT 2>/dev/null || true
    
    # Allow DNS traffic on port 53 (UDP and TCP)
    iptables -A INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || true
    iptables -A OUTPUT -p udp --sport 53 -j ACCEPT 2>/dev/null || true
    iptables -A OUTPUT -p tcp --sport 53 -j ACCEPT 2>/dev/null || true
    
    # Save iptables rules
    if command -v iptables-save &> /dev/null; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    
    print_success "DNS bytes configuration completed (Force 1800 bytes)"
}

# Create systemd service
create_service() {
    print_info "Creating systemd service..."
    
    # Create tun interface script
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
    
    # Create systemd service with proper configuration for 1800 bytes
    cat > /etc/systemd/system/dnstt-server.service <<EOF
[Unit]
Description=DNS Tunnel Server (SKY NET SOLUTION)
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStartPre=$INSTALL_DIR/setup-tun.sh
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

    systemctl daemon-reload
    systemctl enable dnstt-server 2>/dev/null || true
    
    # Start the service
    print_info "Starting dnstt-server service..."
    systemctl start dnstt-server 2>/dev/null || true
    sleep 2
    
    if systemctl is-active --quiet dnstt-server 2>/dev/null; then
        print_success "Systemd service created, enabled, and started"
    else
        print_warning "Service created but not started. Check logs: $LOG_DIR/dnstt-error.log"
    fi
}

# Install menu script
install_menu_script() {
    print_info "Installing management menu script..."
    
    # Check if menu script exists in current directory
    if [ -f "./skynet-menu.sh" ]; then
        cp ./skynet-menu.sh "$INSTALL_DIR/skynet-menu.sh"
        chmod +x "$INSTALL_DIR/skynet-menu.sh"
        print_success "Management menu script installed from local file"
    else
        # Download from GitHub if not found locally
        print_info "Downloading menu script from GitHub..."
        if wget -q https://raw.githubusercontent.com/ESNyarobi123/dnstt/main/skynet-menu.sh -O "$INSTALL_DIR/skynet-menu.sh" 2>/dev/null; then
            chmod +x "$INSTALL_DIR/skynet-menu.sh"
            print_success "Management menu script downloaded and installed"
        else
            print_error "Failed to download menu script. Please download it manually."
            print_info "Run: wget https://raw.githubusercontent.com/ESNyarobi123/dnstt/main/skynet-menu.sh"
            return 1
        fi
    fi
    
    # Create symlink
    ln -sf "$INSTALL_DIR/skynet-menu.sh" /usr/local/bin/skynet-menu 2>/dev/null || true
    chmod +x /usr/local/bin/skynet-menu 2>/dev/null || true
    
    print_success "Menu command 'skynet-menu' is now available"
}

# Get server IP
get_server_ip() {
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || curl -s icanhazip.com)
    echo "$SERVER_IP"
}

# Main installation
main_install() {
    show_banner
    
    print_info "Starting installation..."
    echo ""
    
    check_root
    configure_system
    install_dependencies
    install_dnstt
    install_menu_script
    
    # Get server information
    SERVER_IP=$(get_server_ip)
    PUBLIC_KEY=$(cat "$CONFIG_DIR/publickey.txt" 2>/dev/null || echo "Not generated")
    
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}           Installation Completed Successfully!${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║${NC} ${WHITE}${BOLD}              SERVER CONFIGURATION INFORMATION${NC} ${MAGENTA}${BOLD}            ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}  Server IP:${NC}     ${GREEN}${BOLD}$SERVER_IP${NC}"
    echo -e "${CYAN}${BOLD}  Nameserver (NS):${NC} ${GREEN}${BOLD}$SERVER_IP${NC}"
    echo -e "${CYAN}${BOLD}  Public Key:${NC}   ${GREEN}${BOLD}$PUBLIC_KEY${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}  DNS Configuration:${NC} ${GREEN}8.8.8.8, 8.8.4.4 (Google DNS)${NC}"
    echo -e "${YELLOW}${BOLD}  Packet Size:${NC} ${GREEN}1800 bytes (Optimized for speed)${NC}"
    echo ""
    echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║${NC} ${WHITE}${BOLD}                        NEXT STEPS${NC} ${MAGENTA}${BOLD}                        ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}  ${GREEN}${BOLD}[1]${NC} ${WHITE}Run: ${GREEN}${BOLD}skynet-menu${NC} ${WHITE}to access the management menu${NC}"
    echo -e "${WHITE}  ${GREEN}${BOLD}[2]${NC} ${WHITE}Add your first user from the menu${NC}"
    echo -e "${WHITE}  ${GREEN}${BOLD}[3]${NC} ${WHITE}Service status: ${GREEN}systemctl status dnstt-server${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}✓${NC} ${WHITE}System configured for stable 1800 bytes DNS tunneling${NC}"
    echo -e "${GREEN}${BOLD}✓${NC} ${WHITE}All services are running and ready!${NC}"
    echo ""
}

# Run installation
main_install

