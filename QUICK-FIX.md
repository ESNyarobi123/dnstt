# Quick Fix - Install Menu Script

Run these commands on your VPS to install the menu script:

```bash
# Create directory
sudo mkdir -p /opt/skynet

# Download menu script
sudo wget https://raw.githubusercontent.com/ESNyarobi123/dnstt/main/skynet-menu.sh -O /opt/skynet/skynet-menu.sh

# Make it executable
sudo chmod +x /opt/skynet/skynet-menu.sh

# Create symlink so you can run 'skynet-menu' from anywhere
sudo ln -sf /opt/skynet/skynet-menu.sh /usr/local/bin/skynet-menu
sudo chmod +x /usr/local/bin/skynet-menu

# Test it
sudo skynet-menu
```

Or use this one-liner:

```bash
sudo mkdir -p /opt/skynet && sudo wget https://raw.githubusercontent.com/ESNyarobi123/dnstt/main/skynet-menu.sh -O /opt/skynet/skynet-menu.sh && sudo chmod +x /opt/skynet/skynet-menu.sh && sudo ln -sf /opt/skynet/skynet-menu.sh /usr/local/bin/skynet-menu && sudo chmod +x /usr/local/bin/skynet-menu && echo "✓ Menu installed! Run: sudo skynet-menu"
```

