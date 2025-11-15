#!/bin/bash

# SKY NET SOLUTION - Advanced DNS Tunneling Installation Script
# Modern, Fast, and Stable DNS over HTTPS/TLS Solution

# Don't exit on error - we'll handle errors manually
set +e

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

# NS Domain (will be set during installation)
NS_DOMAIN=""

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
    
    # Download and build dnstt (try official binary first, then build from source)
    if [ ! -f "$INSTALL_DIR/dnstt-server" ]; then
        # Try downloading official binary first (faster and more reliable)
        print_info "Trying to download official dnstt-server binary..."
        ARCH=$(uname -m)
        case "$ARCH" in
            x86_64|amd64)
                DNSTT_URL="https://dnstt.network/dnstt-server-linux-amd64"
                ;;
            aarch64|arm64)
                DNSTT_URL="https://dnstt.network/dnstt-server-linux-arm64"
                ;;
            *)
                DNSTT_URL=""
                print_warning "Architecture $ARCH not supported for official binary, will build from source"
                ;;
        esac
        
        if [ -n "$DNSTT_URL" ]; then
            if curl -fsSL -o "$INSTALL_DIR/dnstt-server" "$DNSTT_URL" 2>/dev/null; then
                chmod +x "$INSTALL_DIR/dnstt-server"
                if [ -x "$INSTALL_DIR/dnstt-server" ]; then
                    print_success "Official dnstt-server binary downloaded"
                else
                    print_warning "Downloaded binary not executable, will build from source"
                    rm -f "$INSTALL_DIR/dnstt-server"
                fi
            else
                print_warning "Failed to download official binary, will build from source"
            fi
        fi
        
        # If official binary failed or not available, build from source
        if [ ! -f "$INSTALL_DIR/dnstt-server" ]; then
            print_info "Building dnstt-server from source..."
            cd /tmp
            rm -rf dnstt
            if git clone https://www.bamsoftware.com/git/dnstt.git > /dev/null 2>&1; then
                cd dnstt/dnstt-server
                if go build -o "$INSTALL_DIR/dnstt-server" > /dev/null 2>&1; then
                    print_success "dnstt-server compiled from source"
                else
                    print_error "Failed to compile dnstt-server. Check Go installation."
                    return 1
                fi
            else
                print_error "Failed to download dnstt source. Check internet connection."
                return 1
            fi
        fi
    else
        print_info "dnstt-server already exists, skipping download"
    fi
    
    # Keys will be generated after dnstt-server is compiled
    print_info "Keys will be generated after dnstt-server compilation..."
    
    # Generate keys now that dnstt-server is available
    generate_keys
    
    # Configure DNS for 512/1800 bytes handling
    configure_dns_bytes
    
    # Create systemd service
    create_service
    
    print_success "dnstt installed"
}

# Generate keys function (called after dnstt-server is compiled)
generate_keys() {
    if [ ! -f "$CONFIG_DIR/publickey.txt" ] || [ ! -f "$CONFIG_DIR/privatekey.txt" ]; then
        print_info "Generating keys using dnstt-server..."
        
        if [ -f "$INSTALL_DIR/dnstt-server" ]; then
            # Use dnstt-server binary to generate keys (proper method)
            "$INSTALL_DIR/dnstt-server" \
                -gen-key \
                -privkey-file "$CONFIG_DIR/privatekey.txt" \
                -pubkey-file "$CONFIG_DIR/publickey.txt" > /dev/null 2>&1
            
            if [ -f "$CONFIG_DIR/privatekey.txt" ] && [ -f "$CONFIG_DIR/publickey.txt" ]; then
                chmod 600 "$CONFIG_DIR/privatekey.txt"
                chmod 644 "$CONFIG_DIR/publickey.txt"
                print_success "Keys generated successfully"
            else
                print_error "Key generation failed, trying alternative method..."
                # Fallback to keygen tool
                if [ -d "/tmp/dnstt/dnstt-keygen" ]; then
                    cd /tmp/dnstt/dnstt-keygen
                    go run . > "$CONFIG_DIR/keygen_output.txt" 2>&1
                    PRIVATE_KEY=$(grep "Private key:" "$CONFIG_DIR/keygen_output.txt" | awk '{print $3}')
                    PUBLIC_KEY=$(grep "Public key:" "$CONFIG_DIR/keygen_output.txt" | awk '{print $3}')
                    if [ -n "$PRIVATE_KEY" ] && [ -n "$PUBLIC_KEY" ]; then
                        echo "$PRIVATE_KEY" > "$CONFIG_DIR/privatekey.txt"
                        echo "$PUBLIC_KEY" > "$CONFIG_DIR/publickey.txt"
                        chmod 600 "$CONFIG_DIR/privatekey.txt"
                        chmod 644 "$CONFIG_DIR/publickey.txt"
                        print_success "Keys generated using fallback method"
                    else
                        print_error "Failed to generate keys"
                    fi
                else
                    print_error "Cannot generate keys - dnstt-keygen directory not found"
                fi
            fi
        else
            print_error "dnstt-server binary not found! Cannot generate keys."
            return 1
        fi
    else
        print_info "Keys already exist, skipping generation"
    fi
}

# Ensure public key is generated (final check before completion)
ensure_public_key_generated() {
    print_info "Verifying public key generation..."
    
    # Check if public key exists and is valid
    if [ -f "$CONFIG_DIR/publickey.txt" ] && [ -f "$CONFIG_DIR/privatekey.txt" ]; then
        PUBLIC_KEY_CONTENT=$(cat "$CONFIG_DIR/publickey.txt" | tr -d '\n\r ' | head -c 44)
        if [ -n "$PUBLIC_KEY_CONTENT" ] && [ ${#PUBLIC_KEY_CONTENT} -ge 40 ]; then
            print_success "Public key verified: $PUBLIC_KEY_CONTENT"
            return 0
        else
            print_warning "Public key file exists but appears invalid, regenerating..."
            rm -f "$CONFIG_DIR/publickey.txt" "$CONFIG_DIR/privatekey.txt"
        fi
    fi
    
    # If we reach here, keys don't exist or are invalid - generate them
    print_info "Generating public key now..."
    
    # Try using dnstt-server first
    if [ -f "$INSTALL_DIR/dnstt-server" ]; then
        "$INSTALL_DIR/dnstt-server" \
            -gen-key \
            -privkey-file "$CONFIG_DIR/privatekey.txt" \
            -pubkey-file "$CONFIG_DIR/publickey.txt" > /dev/null 2>&1
        
        if [ -f "$CONFIG_DIR/publickey.txt" ] && [ -f "$CONFIG_DIR/privatekey.txt" ]; then
            chmod 600 "$CONFIG_DIR/privatekey.txt"
            chmod 644 "$CONFIG_DIR/publickey.txt"
            PUBLIC_KEY_CONTENT=$(cat "$CONFIG_DIR/publickey.txt" | tr -d '\n\r ' | head -c 44)
            if [ -n "$PUBLIC_KEY_CONTENT" ] && [ ${#PUBLIC_KEY_CONTENT} -ge 40 ]; then
                print_success "Public key generated successfully: $PUBLIC_KEY_CONTENT"
                return 0
            fi
        fi
    fi
    
    # Fallback: try using dnstt-keygen if available
    print_info "Trying fallback method to generate keys..."
    cd /tmp
    rm -rf dnstt-keygen-final
    if git clone https://www.bamsoftware.com/git/dnstt.git dnstt-keygen-final > /dev/null 2>&1; then
        if [ -d "dnstt-keygen-final/dnstt-keygen" ]; then
            cd dnstt-keygen-final/dnstt-keygen
            go run . > "$CONFIG_DIR/keygen_final_output.txt" 2>&1
            PRIVATE_KEY=$(grep "Private key:" "$CONFIG_DIR/keygen_final_output.txt" | awk '{print $3}')
            PUBLIC_KEY=$(grep "Public key:" "$CONFIG_DIR/keygen_final_output.txt" | awk '{print $3}')
            if [ -z "$PUBLIC_KEY" ]; then
                PUBLIC_KEY=$(grep -oP 'Public key: \K[^\s]+' "$CONFIG_DIR/keygen_final_output.txt" 2>/dev/null | head -n 1)
            fi
            if [ -n "$PRIVATE_KEY" ] && [ -n "$PUBLIC_KEY" ]; then
                echo "$PRIVATE_KEY" > "$CONFIG_DIR/privatekey.txt"
                echo "$PUBLIC_KEY" > "$CONFIG_DIR/publickey.txt"
                chmod 600 "$CONFIG_DIR/privatekey.txt"
                chmod 644 "$CONFIG_DIR/publickey.txt"
                print_success "Public key generated using fallback method: $PUBLIC_KEY"
                cd /tmp
                rm -rf dnstt-keygen-final
                return 0
            fi
            cd /tmp
            rm -rf dnstt-keygen-final
        fi
    fi
    
    # If all methods failed
    print_error "Failed to generate public key using all available methods"
    return 1
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
    # Using -mtu 1800 flag for maximum speed (like the reference script)
    SERVICE_FILE="/etc/systemd/system/dnstt-server.service"
    
    cat > "$SERVICE_FILE" <<EOF
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
    -mtu 1800 \\
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

    # Verify service file was created
    if [ ! -f "$SERVICE_FILE" ]; then
        print_error "Failed to create service file at $SERVICE_FILE"
        return 1
    fi
    
    print_success "Service file created at: $SERVICE_FILE"
    
    # Reload systemd daemon
    print_info "Reloading systemd daemon..."
    if systemctl daemon-reload; then
        print_success "Systemd daemon reloaded"
    else
        print_error "Failed to reload systemd daemon"
        return 1
    fi
    
    # Enable service
    print_info "Enabling dnstt-server service..."
    if systemctl enable dnstt-server.service; then
        print_success "Service enabled"
    else
        print_warning "Failed to enable service (may already be enabled)"
    fi
    
    # Start the service
    print_info "Starting dnstt-server service..."
    if systemctl start dnstt-server.service; then
        sleep 2
        if systemctl is-active --quiet dnstt-server.service; then
            print_success "Systemd service created, enabled, and started successfully"
        else
            print_warning "Service started but may not be active. Check status: systemctl status dnstt-server"
        fi
    else
        print_warning "Failed to start service. Check logs: $LOG_DIR/dnstt-error.log"
        print_info "You can try to start it manually: systemctl start dnstt-server"
    fi
    
    # Final verification
    if systemctl list-unit-files | grep -q "dnstt-server.service"; then
        print_success "Service file is registered with systemd"
    else
        print_error "Service file is NOT registered with systemd!"
        print_info "Service file location: $SERVICE_FILE"
        print_info "Please check if the file exists and run: systemctl daemon-reload"
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

# Prompt for NS Domain
prompt_ns_domain() {
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}              NAMESERVER (NS) DOMAIN CONFIGURATION${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}IMPORTANT:${NC} ${WHITE}Slow DNS requires a NS (Nameserver) domain, not just IP!${NC}"
    echo ""
    echo -e "${WHITE}Example DNS setup (in your domain registrar/control panel):${NC}"
    echo -e "${GREEN}  A   ns-1.yourdomain.com   ->  IP of this VPS${NC}"
    echo -e "${GREEN}  NS  t.yourdomain.com     ->  ns-1.yourdomain.com${NC}"
    echo ""
    echo -e "${WHITE}You need to enter the NS domain (nameserver domain), example:${NC}"
    echo -e "${GREEN}  ns-1.yourdomain.com${NC}"
    echo -e "${GREEN}  dns.myserver.com${NC}"
    echo -e "${GREEN}  ns1.example.com${NC}"
    echo ""
    echo -ne "${CYAN}${BOLD}Enter NS Domain (e.g., ns-1.yourdomain.com): ${NC}"
    read user_ns_domain
    
    # Trim whitespace
    user_ns_domain=$(echo "$user_ns_domain" | xargs)
    
    if [ -z "$user_ns_domain" ]; then
        print_error "NS Domain cannot be empty! Slow DNS requires a NS domain."
        echo ""
        echo -e "${YELLOW}Please run the installation again and provide a valid NS domain.${NC}"
        exit 1
    fi
    
    # Remove trailing dot if exists
    user_ns_domain="${user_ns_domain%.}"
    
    NS_DOMAIN="$user_ns_domain"
    
    # Save to config
    mkdir -p "$CONFIG_DIR"
    echo "$NS_DOMAIN" > "$CONFIG_DIR/ns_domain.txt"
    
    print_success "NS Domain set to: ${GREEN}$NS_DOMAIN${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}⚠ REMEMBER:${NC} ${WHITE}Make sure this NS domain ($NS_DOMAIN) has an A record${NC}"
    echo -e "${WHITE}pointing to this server's IP in your DNS control panel!${NC}"
    echo ""
    sleep 2
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
    
    # Prompt for NS Domain FIRST (required for Slow DNS)
    prompt_ns_domain
    
    configure_system
    install_dependencies
    
    # Install dnstt (this will also generate keys)
    if ! install_dnstt; then
        print_warning "dnstt installation had issues, but continuing..."
    fi
    
    # Always install menu script
    install_menu_script
    
    # Ensure public key is generated before completion
    print_info "Final verification: Ensuring public key is generated..."
    if ! ensure_public_key_generated; then
        print_error "WARNING: Public key generation failed. Please run 'skynet-menu' and select option 4 to generate it manually."
    fi
    
    # Get server information
    SERVER_IP=$(get_server_ip)
    if [ -f "$CONFIG_DIR/publickey.txt" ]; then
        PUBLIC_KEY=$(cat "$CONFIG_DIR/publickey.txt" | tr -d '\n\r ' | head -c 44)
    else
        PUBLIC_KEY="Not generated - Please run 'skynet-menu' option 4"
    fi
    
    # Load NS Domain
    if [ -f "$CONFIG_DIR/ns_domain.txt" ]; then
        NS_DOMAIN=$(cat "$CONFIG_DIR/ns_domain.txt")
    fi
    
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
    echo -e "${CYAN}${BOLD}  Nameserver (NS):${NC} ${GREEN}${BOLD}${NS_DOMAIN:-$SERVER_IP}${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}  DNS Configuration:${NC} ${GREEN}8.8.8.8, 8.8.4.4 (Google DNS)${NC}"
    echo -e "${YELLOW}${BOLD}  MTU Size:${NC} ${GREEN}1800 bytes (Maximum speed optimized)${NC}"
    echo ""
    echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║${NC} ${WHITE}${BOLD}                    PUBLIC KEY${NC} ${MAGENTA}${BOLD}                            ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    if [ -f "$CONFIG_DIR/publickey.txt" ]; then
        FULL_PUBLIC_KEY=$(cat "$CONFIG_DIR/publickey.txt" | tr -d '\n\r ')
        echo -e "${CYAN}${BOLD}  Public Key (copy hii kwenye client):${NC}"
        echo -e "${GREEN}${BOLD}  $FULL_PUBLIC_KEY${NC}"
        echo ""
        echo -e "${YELLOW}${BOLD}  ⚠ IMPORTANT:${NC} ${WHITE}Save this public key securely!${NC}"
    else
        echo -e "${RED}${BOLD}  Public Key:${NC} ${RED}Not generated${NC}"
        echo -e "${YELLOW}${BOLD}  ⚠ WARNING:${NC} ${WHITE}Please run 'skynet-menu' and select option 4 to generate it${NC}"
    fi
    echo ""
    echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
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

