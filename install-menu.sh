#!/bin/bash

# Quick script to install skynet-menu command
# Run this if the menu wasn't installed during main installation

INSTALL_DIR="/opt/skynet"

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

echo "[*] Installing skynet-menu command..."

# Create directory if not exists
mkdir -p "$INSTALL_DIR"

# Download menu script from GitHub
if wget -q https://raw.githubusercontent.com/ESNyarobi123/dnstt/main/skynet-menu.sh -O "$INSTALL_DIR/skynet-menu.sh" 2>/dev/null; then
    chmod +x "$INSTALL_DIR/skynet-menu.sh"
    echo "[✓] Menu script downloaded"
else
    echo "[✗] Failed to download. Trying with curl..."
    if curl -s https://raw.githubusercontent.com/ESNyarobi123/dnstt/main/skynet-menu.sh -o "$INSTALL_DIR/skynet-menu.sh" 2>/dev/null; then
        chmod +x "$INSTALL_DIR/skynet-menu.sh"
        echo "[✓] Menu script downloaded"
    else
        echo "[✗] Failed to download menu script"
        echo "Please download it manually:"
        echo "wget https://raw.githubusercontent.com/ESNyarobi123/dnstt/main/skynet-menu.sh"
        exit 1
    fi
fi

# Create symlink
ln -sf "$INSTALL_DIR/skynet-menu.sh" /usr/local/bin/skynet-menu 2>/dev/null || true
chmod +x /usr/local/bin/skynet-menu 2>/dev/null || true

echo "[✓] skynet-menu command installed successfully!"
echo ""
echo "You can now run: sudo skynet-menu"

