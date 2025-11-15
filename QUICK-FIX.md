# Quick Fix Guide

## Fix Missing Service File

If you get error: `Unit dnstt-server.service could not be found`

**Option 1: Use fix-service.sh script**

```bash
# Download and run fix script
sudo wget https://raw.githubusercontent.com/ESNyarobi123/dnstt/main/fix-service.sh -O /tmp/fix-service.sh
sudo chmod +x /tmp/fix-service.sh
sudo bash /tmp/fix-service.sh
```

**Option 2: Manual fix**

```bash
# Check if service file exists
ls -la /etc/systemd/system/dnstt-server.service

# If missing, create it manually:
sudo nano /etc/systemd/system/dnstt-server.service
```

Then paste this content:

```ini
[Unit]
Description=DNS Tunnel Server (SKY NET SOLUTION)
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/skynet
ExecStartPre=/opt/skynet/setup-tun.sh
ExecStart=/opt/skynet/dnstt-server -udp :53 \
    -mtu 1800 \
    -privkey-file /etc/skynet/privatekey.txt \
    -pubkey-file /etc/skynet/publickey.txt \
    -tun-dev tun0 \
    -tun-addr 10.0.0.1/24 \
    -tun-dns 8.8.8.8:53
Restart=always
RestartSec=5
StandardOutput=append:/var/log/skynet/dnstt.log
StandardError=append:/var/log/skynet/dnstt-error.log
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

Then reload and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable dnstt-server
sudo systemctl start dnstt-server
sudo systemctl status dnstt-server
```

---

## Install Menu Script

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

