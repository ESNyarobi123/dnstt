#!/bin/bash

# Setup script to install skynet-menu command globally

INSTALL_DIR="/opt/skynet"
MENU_SCRIPT="$INSTALL_DIR/skynet-menu.sh"

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Copy menu script to install directory
if [ -f "skynet-menu.sh" ]; then
    mkdir -p "$INSTALL_DIR"
    cp skynet-menu.sh "$MENU_SCRIPT"
    chmod +x "$MENU_SCRIPT"
    echo "Menu script copied to $MENU_SCRIPT"
else
    echo "Error: skynet-menu.sh not found!"
    exit 1
fi

# Create symlink in /usr/local/bin
ln -sf "$MENU_SCRIPT" /usr/local/bin/skynet-menu
chmod +x /usr/local/bin/skynet-menu

echo "✓ skynet-menu command installed successfully!"
echo "You can now run 'skynet-menu' from anywhere"

