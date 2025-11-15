# SKY NET SOLUTION - Advanced DNS Tunneling

Modern, fast, and stable DNS over HTTPS/TLS solution with beautiful management interface.

## Features

- 🚀 **Modern Installation**: One-command installation script
- 🎨 **Beautiful UI**: Colorful, user-friendly menu interface
- 👥 **User Management**: Add users with username, password, and expiration date
- 🔑 **Key Management**: Generate and manage public keys
- 🌐 **Nameserver Management**: Change nameserver for all users
- 📊 **User Display**: View all users with their credentials
- ⚡ **Optimized**: Handles 512/1800 bytes requests properly and stably
- 🔒 **Secure**: Uses Google DNS (8.8.8.8, 8.8.4.4)

## Installation

1. **Download the installation script:**
   ```bash
   wget https://raw.githubusercontent.com/your-repo/dnstt/main/install.sh
   ```

2. **Make it executable:**
   ```bash
   chmod +x install.sh
   ```

3. **Run the installation:**
   ```bash
   sudo ./install.sh
   ```

The script will:
- Disable UFW firewall
- Disable systemd-resolved
- Configure Google DNS (8.8.8.8, 8.8.4.4) in `/etc/resolv.conf`
- Install all dependencies
- Install and configure dnstt
- Generate public/private keys
- Set up systemd service

## Usage

After installation, access the management menu:

```bash
sudo skynet-menu
```

Or run directly:

```bash
sudo ./skynet-menu.sh
```

## Menu Options

1. **Add New User**: Create a new user with username, password, and expiration date
2. **Show All Users**: Display all users with their credentials, NS, and public key
3. **Change Nameserver**: Update nameserver for all users
4. **Generate New Public Key**: Create a new public key and update all users
5. **Show Server Information**: Display server IP, nameserver, public key, and user count

## User Information Format

When you add a user, you'll receive:
- Username
- Password
- Expiration Date
- Nameserver (NS)
- Public Key

## System Requirements

- Ubuntu/Debian or CentOS/RHEL
- Root access
- Internet connection
- At least 512MB RAM
- 1GB free disk space

## Configuration

- Installation directory: `/opt/skynet`
- Configuration directory: `/etc/skynet`
- Data directory: `/var/lib/skynet`
- Log directory: `/var/log/skynet`

## DNS Configuration

The system is optimized to handle:
- **512 bytes**: When network providers request 512 bytes
- **1800 bytes**: Maximum throughput for better performance

The system automatically handles both sizes properly and stably.

## Service Management

Start the service:
```bash
sudo systemctl start dnstt-server
```

Stop the service:
```bash
sudo systemctl stop dnstt-server
```

Check status:
```bash
sudo systemctl status dnstt-server
```

View logs:
```bash
tail -f /var/log/skynet/dnstt.log
```

## Support

For issues or questions, please check the logs in `/var/log/skynet/`

## License

This project is provided as-is for educational purposes.

---

**SKY NET SOLUTION** - Advanced DNS Tunneling Solution v2.0

