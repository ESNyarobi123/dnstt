#!/bin/bash

# SKY NET SOLUTION - Management Menu
# Beautiful and Modern User Interface

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
CONFIG_DIR="/etc/skynet"
DATA_DIR="/var/lib/skynet"
INSTALL_DIR="/opt/skynet"

# Create data directory if not exists
mkdir -p "$DATA_DIR"

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
    echo "║          Management Panel v2.0                               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print functions
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

# Get server IP
get_server_ip() {
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "Unknown")
    echo "$SERVER_IP"
}

# Get NS Domain
get_ns_domain() {
    if [ -f "$CONFIG_DIR/ns_domain.txt" ]; then
        cat "$CONFIG_DIR/ns_domain.txt" | tr -d '\n\r '
    else
        # Fallback to IP if NS domain not set
        get_server_ip
    fi
}

# Get public key
get_public_key() {
    if [ -f "$CONFIG_DIR/publickey.txt" ]; then
        # Read and trim the key
        cat "$CONFIG_DIR/publickey.txt" | tr -d '\n\r ' | head -c 44
    else
        echo "Not generated"
    fi
}

# Generate random password
generate_password() {
    openssl rand -base64 12 | tr -d "=+/" | cut -c1-16
}

# Add user
add_user() {
    show_banner
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}                    ADD NEW USER${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -ne "${CYAN}Enter Username: ${NC}"
    read username
    
    if [ -z "$username" ]; then
        print_error "Username cannot be empty!"
        sleep 2
        return
    fi
    
    # Check if user exists
    if [ -f "$DATA_DIR/users/$username.conf" ]; then
        print_error "User already exists!"
        sleep 2
        return
    fi
    
    echo -ne "${CYAN}Enter Password (leave empty for auto-generate): ${NC}"
    read -s password
    echo ""
    
    if [ -z "$password" ]; then
        password=$(generate_password)
        print_info "Auto-generated password: $password"
    fi
    
    echo -ne "${CYAN}Enter Expire Date (YYYY-MM-DD): ${NC}"
    read expire_date
    
    if [ -z "$expire_date" ]; then
        print_error "Expire date cannot be empty!"
        sleep 2
        return
    fi
    
    # Create user directory
    mkdir -p "$DATA_DIR/users"
    
    # Save user info
    SERVER_IP=$(get_server_ip)
    NS_DOMAIN=$(get_ns_domain)
    PUBLIC_KEY=$(get_public_key)
    
    cat > "$DATA_DIR/users/$username.conf" <<EOF
USERNAME=$username
PASSWORD=$password
EXPIRE_DATE=$expire_date
CREATED_DATE=$(date +%Y-%m-%d)
NAMESERVER=$NS_DOMAIN
PUBLIC_KEY=$PUBLIC_KEY
EOF
    
    print_success "User created successfully!"
    echo ""
    echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║${NC} ${WHITE}${BOLD}                    USER INFORMATION${NC} ${MAGENTA}${BOLD}                    ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}  Username:${NC}     ${GREEN}${BOLD}$username${NC}"
    echo -e "${CYAN}${BOLD}  Password:${NC}     ${GREEN}${BOLD}$password${NC}"
    echo -e "${CYAN}${BOLD}  Expire Date:${NC}  ${GREEN}${BOLD}$expire_date${NC}"
    echo -e "${CYAN}${BOLD}  Nameserver (NS):${NC} ${GREEN}${BOLD}$NS_DOMAIN${NC}"
    echo -e "${CYAN}${BOLD}  Public Key:${NC}   ${GREEN}${BOLD}$PUBLIC_KEY${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}  ⚠ IMPORTANT:${NC} ${WHITE}Save this information securely!${NC}"
    echo ""
    echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Show users
show_users() {
    show_banner
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}                    ALL USERS${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ ! -d "$DATA_DIR/users" ] || [ -z "$(ls -A $DATA_DIR/users/*.conf 2>/dev/null)" ]; then
        print_warning "No users found!"
        echo ""
        read -p "$(echo -e ${YELLOW}Press Enter to continue...${NC})"
        return
    fi
    
    SERVER_IP=$(get_server_ip)
    NS_DOMAIN=$(get_ns_domain)
    PUBLIC_KEY=$(get_public_key)
    
    echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║${NC} ${WHITE}${BOLD}              CURRENT SERVER INFORMATION${NC} ${MAGENTA}${BOLD}              ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}  Server IP:${NC}       ${GREEN}${BOLD}$SERVER_IP${NC}"
    echo -e "${CYAN}${BOLD}  Nameserver (NS):${NC} ${GREEN}${BOLD}$NS_DOMAIN${NC}"
    echo -e "${CYAN}${BOLD}  Public Key:${NC}     ${GREEN}${BOLD}$PUBLIC_KEY${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    count=1
    for user_file in "$DATA_DIR/users"/*.conf; do
        if [ -f "$user_file" ]; then
            source "$user_file"
            echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${MAGENTA}${BOLD}║${NC} ${WHITE}${BOLD}[$count] User Account: ${GREEN}${BOLD}$USERNAME${NC} ${MAGENTA}${BOLD}                    ║${NC}"
            echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
            echo -e "${CYAN}${BOLD}    Username:${NC}     ${GREEN}$USERNAME${NC}"
            echo -e "${CYAN}${BOLD}    Password:${NC}     ${GREEN}$PASSWORD${NC}"
            echo -e "${CYAN}${BOLD}    Expire Date:${NC}  ${GREEN}$EXPIRE_DATE${NC}"
            echo -e "${CYAN}${BOLD}    Created:${NC}      ${GREEN}$CREATED_DATE${NC}"
            echo -e "${CYAN}${BOLD}    Nameserver (NS):${NC} ${GREEN}$NAMESERVER${NC}"
            echo -e "${CYAN}${BOLD}    Public Key:${NC}   ${GREEN}$PUBLIC_KEY${NC}"
            echo ""
            ((count++))
        fi
    done
    
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Change nameserver
change_nameserver() {
    show_banner
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}                 CHANGE NAMESERVER${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    CURRENT_NS=$(get_ns_domain)
    echo -e "${WHITE}Current Nameserver (NS):${NC} ${GREEN}$CURRENT_NS${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}Note:${NC} ${WHITE}Enter NS domain (e.g., ns-1.yourdomain.com), not IP!${NC}"
    echo ""
    echo -ne "${CYAN}Enter New NS Domain (e.g., ns-1.yourdomain.com): ${NC}"
    read new_ns
    
    if [ -z "$new_ns" ]; then
        print_error "NS Domain cannot be empty!"
        sleep 2
        return
    fi
    
    # Trim and remove trailing dot
    new_ns=$(echo "$new_ns" | xargs)
    new_ns="${new_ns%.}"
    
    # Basic domain validation (must contain at least one dot)
    if [[ ! "$new_ns" =~ \. ]]; then
        print_error "Invalid domain format! Must be like: ns-1.yourdomain.com"
        sleep 2
        return
    fi
    
    # Update all users
    if [ -d "$DATA_DIR/users" ]; then
        for user_file in "$DATA_DIR/users"/*.conf; do
            if [ -f "$user_file" ]; then
                sed -i "s/NAMESERVER=.*/NAMESERVER=$new_ns/" "$user_file"
            fi
        done
    fi
    
    # Save to config
    echo "$new_ns" > "$CONFIG_DIR/ns_domain.txt"
    
    print_success "Nameserver changed to: $new_ns"
    echo ""
    print_info "All users have been updated with the new nameserver"
    echo ""
    echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║${NC} ${WHITE}${BOLD}                    UPDATED INFORMATION${NC} ${MAGENTA}${BOLD}                    ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}  New Nameserver (NS):${NC} ${GREEN}${BOLD}$new_ns${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}  ⚠ Note:${NC} ${WHITE}All existing users now use this nameserver${NC}"
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Generate new public key
generate_new_key() {
    show_banner
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}              GENERATE NEW PUBLIC KEY${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    OLD_KEY=$(get_public_key)
    echo -e "${WHITE}Current Public Key:${NC} ${GREEN}$OLD_KEY${NC}"
    echo ""
    
    echo -ne "${YELLOW}Are you sure you want to generate a new public key? (y/n): ${NC}"
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "Operation cancelled"
        sleep 2
        return
    fi
    
    print_info "Generating new public key..."
    
    # Use dnstt-server binary to generate keys (better method)
    if [ -f "$INSTALL_DIR/dnstt-server" ]; then
        # Generate new keys using dnstt-server
        if "$INSTALL_DIR/dnstt-server" \
            -gen-key \
            -privkey-file "$CONFIG_DIR/privatekey.txt" \
            -pubkey-file "$CONFIG_DIR/publickey.txt" > /dev/null 2>&1; then
            
            if [ -f "$CONFIG_DIR/publickey.txt" ] && [ -f "$CONFIG_DIR/privatekey.txt" ]; then
                NEW_KEY=$(cat "$CONFIG_DIR/publickey.txt" | tr -d '\n\r ')
                chmod 600 "$CONFIG_DIR/privatekey.txt"
                chmod 644 "$CONFIG_DIR/publickey.txt"
                print_success "Keys generated successfully using dnstt-server"
            else
                print_error "Key files were not created, trying fallback..."
                NEW_KEY=""
            fi
        else
            print_error "dnstt-server key generation failed, trying fallback..."
            NEW_KEY=""
        fi
    else
        print_warning "dnstt-server binary not found at $INSTALL_DIR/dnstt-server"
        print_info "Checking alternative locations..."
        
        # Try to find dnstt-server in common locations
        DNSTT_BIN=""
        if [ -f "/opt/skynet/dnstt-server" ]; then
            DNSTT_BIN="/opt/skynet/dnstt-server"
            print_info "Found dnstt-server at $DNSTT_BIN"
        elif [ -f "/usr/local/bin/dnstt-server" ]; then
            DNSTT_BIN="/usr/local/bin/dnstt-server"
            print_info "Found dnstt-server at $DNSTT_BIN"
        elif [ -f "/usr/bin/dnstt-server" ]; then
            DNSTT_BIN="/usr/bin/dnstt-server"
            print_info "Found dnstt-server at $DNSTT_BIN"
        fi
        
        if [ -n "$DNSTT_BIN" ] && [ -f "$DNSTT_BIN" ]; then
            # Use found binary to generate keys
            if "$DNSTT_BIN" \
                -gen-key \
                -privkey-file "$CONFIG_DIR/privatekey.txt" \
                -pubkey-file "$CONFIG_DIR/publickey.txt" > /dev/null 2>&1; then
                
                if [ -f "$CONFIG_DIR/publickey.txt" ] && [ -f "$CONFIG_DIR/privatekey.txt" ]; then
                    NEW_KEY=$(cat "$CONFIG_DIR/publickey.txt" | tr -d '\n\r ')
                    chmod 600 "$CONFIG_DIR/privatekey.txt"
                    chmod 644 "$CONFIG_DIR/publickey.txt"
                    print_success "Keys generated successfully using dnstt-server"
                else
                    print_error "Key files were not created"
                    NEW_KEY=""
                fi
            else
                print_error "Key generation failed with found binary"
                NEW_KEY=""
            fi
        else
            print_error "dnstt-server binary not found anywhere!"
            NEW_KEY=""
        fi
    fi
    
    # Fallback method if dnstt-server method failed
    if [ -z "$NEW_KEY" ] || [ ! -f "$CONFIG_DIR/publickey.txt" ]; then
        print_info "Trying fallback key generation method..."
        cd /tmp
        rm -rf dnstt-keygen-tmp
        if git clone https://www.bamsoftware.com/git/dnstt.git dnstt-keygen-tmp > /dev/null 2>&1; then
            if [ -d "dnstt-keygen-tmp/dnstt-keygen" ]; then
                cd dnstt-keygen-tmp/dnstt-keygen
                go run . > "$CONFIG_DIR/keygen_output_new.txt" 2>&1
                
                # Extract keys
                PRIVATE_KEY=$(grep "Private key:" "$CONFIG_DIR/keygen_output_new.txt" | awk '{print $3}')
                NEW_KEY=$(grep "Public key:" "$CONFIG_DIR/keygen_output_new.txt" | awk '{print $3}')
                
                if [ -z "$NEW_KEY" ]; then
                    # Try alternative extraction
                    NEW_KEY=$(grep -oP 'Public key: \K[^\s]+' "$CONFIG_DIR/keygen_output_new.txt" 2>/dev/null | head -n 1)
                fi
                
                if [ -n "$PRIVATE_KEY" ] && [ -n "$NEW_KEY" ]; then
                    echo "$PRIVATE_KEY" > "$CONFIG_DIR/privatekey.txt"
                    echo "$NEW_KEY" > "$CONFIG_DIR/publickey.txt"
                    chmod 600 "$CONFIG_DIR/privatekey.txt"
                    chmod 644 "$CONFIG_DIR/publickey.txt"
                    print_success "Keys generated using fallback method"
                fi
            fi
        fi
    fi
    
    # Final check
    if [ -z "$NEW_KEY" ] || [ ! -f "$CONFIG_DIR/publickey.txt" ]; then
        print_error "Failed to generate keys. Please check dnstt-server installation."
        sleep 3
        return 1
    fi
    
    # Read the actual key from file
    NEW_KEY=$(cat "$CONFIG_DIR/publickey.txt" | tr -d '\n\r ')
    
    # Update all users
    if [ -d "$DATA_DIR/users" ]; then
        for user_file in "$DATA_DIR/users"/*.conf; do
            if [ -f "$user_file" ]; then
                sed -i "s/PUBLIC_KEY=.*/PUBLIC_KEY=$NEW_KEY/" "$user_file"
            fi
        done
    fi
    
    # Restart service if running
    if systemctl is-active --quiet dnstt-server 2>/dev/null; then
        print_info "Restarting dnstt-server service..."
        systemctl restart dnstt-server 2>/dev/null || true
    fi
    
    print_success "New public key generated!"
    echo ""
    echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║${NC} ${WHITE}${BOLD}                    NEW PUBLIC KEY${NC} ${MAGENTA}${BOLD}                        ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}  New Public Key:${NC} ${GREEN}${BOLD}$NEW_KEY${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}  ⚠ Note:${NC} ${WHITE}All existing users have been updated with the new public key${NC}"
    echo -e "${YELLOW}${BOLD}  ⚠ Note:${NC} ${WHITE}Service has been restarted to apply changes${NC}"
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Show server info
show_server_info() {
    show_banner
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}                  SERVER INFORMATION${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    SERVER_IP=$(get_server_ip)
    NS_DOMAIN=$(get_ns_domain)
    PUBLIC_KEY=$(get_public_key)
    USER_COUNT=$(ls -1 "$DATA_DIR/users"/*.conf 2>/dev/null | wc -l)
    
    echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║${NC} ${WHITE}${BOLD}                  SERVER INFORMATION${NC} ${MAGENTA}${BOLD}                    ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}  Server IP:${NC}       ${GREEN}${BOLD}$SERVER_IP${NC}"
    echo -e "${CYAN}${BOLD}  Nameserver (NS):${NC}  ${GREEN}${BOLD}$NS_DOMAIN${NC}"
    echo -e "${CYAN}${BOLD}  Public Key:${NC}      ${GREEN}${BOLD}$PUBLIC_KEY${NC}"
    echo -e "${CYAN}${BOLD}  Total Users:${NC}     ${GREEN}${BOLD}$USER_COUNT${NC}"
    echo ""
    
    # Check service status
    if systemctl is-active --quiet dnstt-server 2>/dev/null; then
        echo -e "${CYAN}${BOLD}  Service Status:${NC}  ${GREEN}${BOLD}✓ Running${NC}"
    else
        echo -e "${CYAN}${BOLD}  Service Status:${NC}  ${RED}${BOLD}✗ Stopped${NC}"
    fi
    
    # Check DNS configuration
    if grep -q "8.8.8.8" /etc/resolv.conf 2>/dev/null; then
        echo -e "${CYAN}${BOLD}  DNS Config:${NC}      ${GREEN}${BOLD}✓ Google DNS (8.8.8.8, 8.8.4.4)${NC}"
    else
        echo -e "${CYAN}${BOLD}  DNS Config:${NC}      ${YELLOW}${BOLD}⚠ Not configured${NC}"
    fi
    
    echo ""
    echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Main menu
main_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}${BOLD}                      MAIN MENU${NC}"
        echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}${BOLD}[1]${NC} ${WHITE}Add New User${NC}"
        echo -e "${GREEN}${BOLD}[2]${NC} ${WHITE}Show All Users${NC}"
        echo -e "${GREEN}${BOLD}[3]${NC} ${WHITE}Change Nameserver${NC}"
        echo -e "${GREEN}${BOLD}[4]${NC} ${WHITE}Generate New Public Key${NC}"
        echo -e "${GREEN}${BOLD}[5]${NC} ${WHITE}Show Server Information${NC}"
        echo -e "${RED}${BOLD}[0]${NC} ${WHITE}Exit${NC}"
        echo ""
        echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -ne "${CYAN}Select option: ${NC}"
    read option
        
        case $option in
            1)
                add_user
                ;;
            2)
                show_users
                ;;
            3)
                change_nameserver
                ;;
            4)
                generate_new_key
                ;;
            5)
                show_server_info
                ;;
            0)
                echo ""
                print_info "Thank you for using SKY NET SOLUTION!"
                echo ""
                exit 0
                ;;
            *)
                print_error "Invalid option!"
                sleep 2
                ;;
        esac
    done
}

# Run main menu
main_menu

